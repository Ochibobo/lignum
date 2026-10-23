module storage.backends.filesystem.writer;

import std.exception : enforce;
import std.stdio : File;
import storage.io.writer : StorageWriter;

/**
 * FileWriter implementation for the filesystem
 */
final class FileSystemFileWriter : StorageWriter
{
private:
    File _file;

public:
    this(const string filePath, WriteMode writeMode)
    {
        enforce(writeMode != WriteMode.NONE, "Write mode cannot be NONE");

        _file = File(filePath, writeMode == WriteMode.WRITE ? "wb" : "ab");
    }

    override void write(in ubyte[] data)
    {
        _file.rawWrite(data);
    }

    override void flush()
    {
        _file.flush();
    }

    override void sync()
    {
        _file.sync();
    }

    override void close()
    {
        _file.close();
    }
}

// The write-mode when opening a file
package enum WriteMode
{
    NONE,
    WRITE,
    APPEND
}
