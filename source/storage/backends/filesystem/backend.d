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
        throw new NotImplementedError("openForRead");
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
        throw new NotImplementedError("openForWrite");
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
        throw new NotImplementedError("openForAppend");
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
