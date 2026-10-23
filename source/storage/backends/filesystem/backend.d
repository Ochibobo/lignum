module storage.backends.filesystem.backend;

import std.file : exists, mkdirRecurse, read, rename;
import std.path : baseName, buildNormalizedPath, buildPath, dirName, isAbsolute;
import std.stdio : File;
import std.typecons : NotImplementedError;
import std.uuid : randomUUID;

import storage.backends.backend : StorageBackend;
import storage.config.options : FileSystemStorageOptions;
import storage.io.reader : StorageReader;
import storage.io.writer : StorageWriter;
import storage.backends.filesystem.reader : FileSystemFileReader;
import storage.backends.filesystem.writer : FileSystemFileWriter, WriteMode;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * Implementation of `StorageBackend` for the local file system.
 */
final class FileSystemBackend : StorageBackend
{
    private string _rootPath;
    private FileSystemStorageOptions _options;

    /**
     * Construct a new `FileSystemBackend`.
     *
     * Params:
     *   `rootPath` - The root path to use for all file operations.
     */
    this(const FileSystemStorageOptions options)
    {
        _rootPath = buildNormalizedPath(options.rootPath);
        _options = options;
        mkdirRecurse(_rootPath);
    }

    override ubyte[] readObject(string key)
    {
        return cast(ubyte[]) read(resolveKey(key));
    }

    override void replaceObject(string key, scope const(ubyte)[] contents)
    {
        auto targetPath = resolveKey(key);
        auto parentPath = dirName(targetPath);
        mkdirRecurse(parentPath);

        auto temporaryPath = buildPath(
            parentPath,
            "." ~ baseName(targetPath) ~ "." ~ randomUUID().toString() ~ ".tmp"
        );

        scope (failure)
        {
            import std.file : remove;

            if (temporaryPath.exists)
                remove(temporaryPath);
        }

        auto file = File(temporaryPath, "wb");
        file.rawWrite(contents);
        file.flush();
        file.sync();
        file.close();
        rename(temporaryPath, targetPath);
    }

    override bool exists(string key)
    {
        return resolveKey(key).exists;
    }

    private string resolveKey(string key) const
    {
        import std.exception : enforce;
        import std.path : pathSplitter;

        enforce(key.length > 0, "Storage key cannot be empty");
        enforce(!key.isAbsolute, "Storage key must be relative");

        foreach (segment; key.pathSplitter)
            enforce(segment != "..", "Storage key cannot escape the backend root");

        return buildNormalizedPath(_rootPath, key);
    }

    /**
     * Open a file for reading.
     *
     * Params:
     *   `fileName` - name of the file to open.
     *
     * Returns:
     *   `StorageReader` for the file.
     */
    override StorageReader openForRead(string fileName)
    {
        return new FileSystemFileReader(resolveKey(fileName));
    }

    /**
     * Open a file for writing.
     *
     * Params:
     *   `fileName` - name of the file to open.
     *
     * Returns:
     *   `StorageWriter` for the file.
     */
    override StorageWriter openForWrite(string fileName)
    {
        return new FileSystemFileWriter(resolveKey(fileName), WriteMode.WRITE);
    }

    /**
     * Open a file for appending.
     *
     * Params:
     *   `fileName` - name of the file to open.
     *
     * Returns:
     *   `StorageWriter` for the file.
     */
    override StorageWriter openForAppend(string fileName)
    {
        return new FileSystemFileWriter(resolveKey(fileName), WriteMode.APPEND);
    }
}

@("FileSystemBackend replaces complete objects") unittest
{
    import std.file : dirEntries, SpanMode, rmdirRecurse, tempDir;
    import std.path : buildPath;

    auto rootPath = buildPath(tempDir(), "duramen-backend-" ~ randomUUID().toString());
    scope (exit)
    {
        if (rootPath.exists)
            rootPath.rmdirRecurse;
    }

    FileSystemStorageOptions options;
    options.rootPath = rootPath;
    auto backend = new FileSystemBackend(options);

    backend.replaceObject("OPTIONS.toml", cast(const(ubyte)[]) "first");
    assert(cast(string) backend.readObject("OPTIONS.toml") == "first");

    backend.replaceObject("OPTIONS.toml", cast(const(ubyte)[]) "second");
    assert(cast(string) backend.readObject("OPTIONS.toml") == "second");

    size_t fileCount;
    foreach (entry; dirEntries(rootPath, SpanMode.shallow))
        ++fileCount;
    assert(fileCount == 1);
}

@("FileSystemBackend rejects keys outside its root") unittest
{
    import std.exception : assertThrown;
    import std.file : rmdirRecurse, tempDir;
    import std.path : buildPath;

    auto rootPath = buildPath(tempDir(), "duramen-backend-" ~ randomUUID().toString());
    scope (exit)
    {
        if (rootPath.exists)
            rootPath.rmdirRecurse;
    }

    FileSystemStorageOptions options;
    options.rootPath = rootPath;
    auto backend = new FileSystemBackend(options);

    assertThrown!Exception(backend.exists("../OPTIONS.toml"));
    assertThrown!Exception(backend.exists(rootPath));
}

@("FileSystemBackend reads and replaces binary objects") unittest
{
    import std.file : rmdirRecurse, tempDir;
    import std.path : buildPath;

    auto rootPath = buildPath(tempDir(), "duramen-backend-" ~ randomUUID().toString());
    scope (exit)
    {
        if (rootPath.exists)
            rootPath.rmdirRecurse;
    }

    FileSystemStorageOptions options;
    options.rootPath = rootPath;
    auto backend = new FileSystemBackend(options);
    immutable ubyte[] expected = [0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF];

    backend.replaceObject("binary.data", expected);

    assert(backend.readObject("binary.data") == expected);
}

@("FileSystemBackend supports empty and nested objects") unittest
{
    import std.file : rmdirRecurse, tempDir;
    import std.path : buildPath;

    auto rootPath = buildPath(tempDir(), "duramen-backend-" ~ randomUUID().toString());
    scope (exit)
    {
        if (rootPath.exists)
            rootPath.rmdirRecurse;
    }

    FileSystemStorageOptions options;
    options.rootPath = rootPath;
    auto backend = new FileSystemBackend(options);

    backend.replaceObject("catalog/empty.data", []);

    assert(backend.exists("catalog/empty.data"));
    assert(backend.readObject("catalog/empty.data").length == 0);
}

@("FileSystemBackend reports missing objects") unittest
{
    import std.file : FileException, rmdirRecurse, tempDir;
    import std.exception : assertThrown;
    import std.path : buildPath;

    auto rootPath = buildPath(tempDir(), "duramen-backend-" ~ randomUUID().toString());
    scope (exit)
    {
        if (rootPath.exists)
            rootPath.rmdirRecurse;
    }

    FileSystemStorageOptions options;
    options.rootPath = rootPath;
    auto backend = new FileSystemBackend(options);

    assert(!backend.exists("missing.data"));
    assertThrown!FileException(backend.readObject("missing.data"));
}
