module storage.backends.filesystem.writer;

import std.exception : enforce;
import std.stdio : File;

import storage.io.writer : StorageWriter;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * FileWriter implementation for the filesystem
 */
final class FileSystemFileWriter : StorageWriter
{
private:
    File _file;
    bool _closed;

public:
    this(const string filePath, WriteMode writeMode)
    {
        enforce(writeMode != WriteMode.NONE, "Write mode cannot be NONE");

        _file = File(filePath, writeMode == WriteMode.WRITE ? "wb" : "ab");
    }

    override void write(in ubyte[] data)
    {
        ensureOpen();
        _file.rawWrite(data);
    }

    override void flush()
    {
        ensureOpen();
        _file.flush();
    }

    override void sync()
    {
        ensureOpen();
        _file.sync();
    }

    override void close()
    {
        if (_closed)
            return;

        _file.close();
        _closed = true;
    }

private:
    void ensureOpen() const
    {
        enforce(!_closed, "Writer is closed");
    }
}

// The write-mode when opening a file
package enum WriteMode
{
    NONE,
    WRITE,
    APPEND
}

@("FileSystemFileWriter writes binary data and truncates existing files") unittest
{
    import std.file : exists, read, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-writer-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, cast(const(ubyte)[]) "existing content");

    auto writer = new FileSystemFileWriter(path, WriteMode.WRITE);
    immutable ubyte[] expected = [0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF];
    writer.write(expected);
    writer.flush();
    writer.sync();
    writer.close();

    assert(cast(ubyte[]) read(path) == expected);
}

@("FileSystemFileWriter appends without replacing existing data") unittest
{
    import std.file : exists, read, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-writer-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, cast(const(ubyte)[]) "first");

    auto writer = new FileSystemFileWriter(path, WriteMode.APPEND);
    writer.write(cast(const(ubyte)[]) "second");
    writer.close();

    assert(cast(string) read(path) == "firstsecond");
}

@("FileSystemFileWriter closes idempotently and rejects later operations") unittest
{
    import std.exception : assertThrown;
    import std.file : exists, remove, tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-writer-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    auto writer = new FileSystemFileWriter(path, WriteMode.WRITE);
    writer.close();
    writer.close();

    assertThrown!Exception(writer.write(cast(const(ubyte)[]) "data"));
    assertThrown!Exception(writer.flush());
    assertThrown!Exception(writer.sync());
}

@("FileSystemFileWriter rejects an unspecified write mode") unittest
{
    import std.exception : assertThrown;

    assertThrown!Exception(new FileSystemFileWriter("unused", WriteMode.NONE));
}
