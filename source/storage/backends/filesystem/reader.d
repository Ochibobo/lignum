module storage.backends.filesystem.reader;

import core.atomic : atomicLoad, atomicStore;
import std.exception : enforce;
import storage.io.reader : RandomAccessReader;

import nativeIO = storage.backends.filesystem.native;

alias NativeHandler = nativeIO.NativeHandle;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * `FileReader` implementation of the filesystem
 */
final class FileSystemFileReader : RandomAccessReader
{
private:
    NativeHandler _handle = nativeIO.invalidHandle;

    NativeHandler requireOpen() shared
    {
        auto handle = cast(NativeHandler) atomicLoad(_handle);
        enforce(handle != nativeIO.invalidHandle, "Reader is closed");
        return handle;
    }

public:
    this(const string filePath) shared
    {
        const handle = nativeIO.openReadOnly(filePath);
        atomicStore(_handle, cast(shared(NativeHandler)) handle);
    }

    override size_t readAt(ulong offset, scope ubyte[] destination) shared
    {
        return nativeIO.readAt(requireOpen(), offset, destination);
    }

    override ulong length() shared
    {
        return nativeIO.fileLength(requireOpen());
    }

    override void close() shared
    {
        auto handle = cast(NativeHandler) atomicLoad(_handle);
        if (handle == nativeIO.invalidHandle)
            return;

        atomicStore(_handle, cast(shared(NativeHandler)) nativeIO.invalidHandle);
        nativeIO.closeFile(handle);
    }
}

@("FileSystemFileReader reads independent offsets without a cursor") unittest
{
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-reader-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, cast(const(ubyte)[]) "abcdefghij");
    auto reader = new shared FileSystemFileReader(path);
    scope (exit)
        reader.close();

    ubyte[3] first;
    ubyte[3] second;

    assert(reader.readAt(3, first) == first.length);
    assert(cast(string) first[] == "def");
    assert(reader.readAt(0, second) == second.length);
    assert(cast(string) second[] == "abc");
}

@("FileSystemFileReader positional reads preserve the sequential cursor") unittest
{
    import storage.io.sequential_reader : SequentialAccessReader;
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-reader-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, cast(const(ubyte)[]) "abcdefghij");
    auto reader = new shared FileSystemFileReader(path);
    scope (exit)
        reader.close();

    ubyte[2] first;
    ubyte[2] positional;
    ubyte[2] continued;
    auto sequential = SequentialAccessReader(atomicLoad(reader));

    assert(sequential.read(first) == first.length);
    assert(reader.readAt(6, positional) == positional.length);
    assert(sequential.position == first.length);
    assert(sequential.read(continued) == continued.length);

    assert(cast(string) first[] == "ab");
    assert(cast(string) positional[] == "gh");
    assert(cast(string) continued[] == "cd");
}

@("FileSystemFileReader reports length and end of file") unittest
{
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-reader-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    immutable ubyte[] expected = [0x00, 0x80, 0xFF];
    write(path, expected);
    auto reader = new shared FileSystemFileReader(path);
    scope (exit)
        reader.close();

    assert(reader.length == expected.length);

    ubyte[4] destination;
    destination[] = 0x55;
    assert(reader.readAt(0, destination) == expected.length);
    assert(destination[0 .. expected.length] == expected);
    assert(destination[$ - 1] == 0x55);
    assert(reader.readAt(expected.length, destination) == 0);
    assert(reader.readAt(expected.length + 10, destination) == 0);
    assert(reader.readAt(1UL << 32, destination) == 0);
    assert(reader.readAt((1UL << 32) + 1, destination) == 0);
}

@("FileSystemFileReader rejects missing files") unittest
{
    import std.exception : assertThrown;
    import std.file : tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "missing-reader-" ~ randomUUID().toString());

    assertThrown!Exception(new shared FileSystemFileReader(path));
}

@("FileSystemFileReader handles Unicode paths and empty files and buffers") unittest
{
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-reader-\u03b1-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, new ubyte[0]);
    auto reader = new shared FileSystemFileReader(path);
    scope (exit)
        reader.close();

    ubyte[1] destination = [0x55];
    assert(reader.length == 0);
    assert(reader.readAt(0, destination[0 .. 0]) == 0);
    assert(reader.readAt(0, destination) == 0);
    assert(destination[0] == 0x55);
}

@("FileSystemFileReader rejects invalid ranges and closes idempotently") unittest
{
    import std.exception : assertThrown;
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-reader-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, "abcdef");
    auto reader = new shared FileSystemFileReader(path);
    scope (exit)
        reader.close();

    ubyte[2] destination;
    assertThrown!Exception(reader.readAt(ulong.max, destination));
    assertThrown!Exception(reader.readAt(cast(ulong) long.max + 1, destination));
    assert(reader.readAt(0, destination) == destination.length);

    reader.close();
    reader.close();
    assertThrown!Exception(reader.readAt(0, destination));
    assertThrown!Exception(reader.readAt(0, destination[0 .. 0]));
    assertThrown!Exception(reader.length());
}

@("FileSystemFileReader observes appends after reaching EOF") unittest
{
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.stdio : File;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-reader-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, "first");
    auto reader = new shared FileSystemFileReader(path);
    scope (exit)
        reader.close();

    ubyte[4] destination;
    assert(reader.readAt(5, destination) == 0);

    auto writer = File(path, "ab");
    writer.rawWrite(cast(const(ubyte)[]) "next");
    writer.close();

    assert(reader.length == 9);
    assert(reader.readAt(5, destination) == destination.length);
    assert(cast(string) destination[] == "next");
}

@("FileSystemFileReader supports concurrent positional reads before owner close") unittest
{
    import core.thread.threadgroup : ThreadGroup;
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;
    import storage.io.sequential_reader : SequentialAccessReader;

    auto path = buildPath(tempDir(), "duramen-reader-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, "abcdefghij");
    auto reader = new shared FileSystemFileReader(path);
    scope (exit)
        reader.close();

    auto workers = new ThreadGroup;
    scope (exit)
        workers.joinAll(false);

    void delegate() makeWorker(shared(RandomAccessReader) source, size_t workerIndex)
    {
        return {
            ubyte[3] destination;
            foreach (iteration; 0 .. 100)
            {
                const offset = (iteration + workerIndex) % 8;
                assert(source.readAt(offset, destination) == destination.length);
                assert(cast(string) destination[] == "abcdefghij"[offset .. offset + 3]);
                assert(source.length == 10);
            }

            auto sequential = SequentialAccessReader(atomicLoad(source), workerIndex);
            ulong position = workerIndex;
            while (true)
            {
                const count = sequential.read(destination);
                if (count == 0)
                    break;
                assert(cast(string) destination[0 .. count] ==
                    "abcdefghij"[cast(size_t) position .. cast(size_t) position + count]);
                position += count;
                assert(sequential.position == position);
            }
            assert(position == 10);
        };
    }

    foreach (workerIndex; 0 .. 4)
        workers.create(makeWorker(atomicLoad(reader), workerIndex));

    workers.joinAll();
}
