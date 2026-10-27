module storage.backends.filesystem.reader;

import std.exception : enforce;
import std.file : exists;
import std.stdio : File;
import storage.io.reader : StorageReader;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * `FileReader` implementation of the filesystem
 */
final class FileSystemFileReader : StorageReader
{
private:
    File _file;

public:
    this(const string filePath)
    {
        enforce(filePath.exists, "File does not exist: " ~ filePath);

        _file = File(filePath, "rb");
    }

    override size_t read(scope ubyte[] destination)
    {
        return _file.rawRead(destination).length;
    }

    override size_t readAt(ulong offset, scope ubyte[] destination)
    {
        const currentPosition = _file.tell();
        scope (exit)
        {
            // Return the file cursor to its original position
            _file.seek(currentPosition);
        }
        _file.seek(offset);
        return _file.rawRead(destination).length;
    }

    override ulong length()
    {
        return _file.size();
    }

    override void close()
    {
        _file.close();
    }
}

@("FileSystemFileReader reads sequentially and advances its cursor") unittest
{
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-reader-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, cast(const(ubyte)[]) "abcdefghij");
    auto reader = new FileSystemFileReader(path);
    scope (exit)
        reader.close();

    ubyte[3] first;
    ubyte[3] second;

    assert(reader.read(first) == first.length);
    assert(cast(string) first[] == "abc");
    assert(reader.read(second) == second.length);
    assert(cast(string) second[] == "def");
}

@("FileSystemFileReader positional reads preserve the sequential cursor") unittest
{
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-reader-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, cast(const(ubyte)[]) "abcdefghij");
    auto reader = new FileSystemFileReader(path);
    scope (exit)
        reader.close();

    ubyte[2] first;
    ubyte[2] positional;
    ubyte[2] continued;

    assert(reader.read(first) == first.length);
    assert(reader.readAt(6, positional) == positional.length);
    assert(reader.read(continued) == continued.length);

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
    auto reader = new FileSystemFileReader(path);
    scope (exit)
        reader.close();

    assert(reader.length == expected.length);

    ubyte[4] destination;
    assert(reader.read(destination) == expected.length);
    assert(destination[0 .. expected.length] == expected);
    assert(reader.read(destination) == 0);
    assert(reader.readAt(expected.length, destination) == 0);
}

@("FileSystemFileReader rejects missing files") unittest
{
    import std.exception : assertThrown;
    import std.file : tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "missing-reader-" ~ randomUUID().toString());

    assertThrown!Exception(new FileSystemFileReader(path));
}
