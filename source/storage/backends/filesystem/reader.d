module storage.backends.filesystem.reader;

import std.exception : enforce;
import std.file : exists;
import std.stdio : File;
import storage.io.reader : StorageReader;

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
