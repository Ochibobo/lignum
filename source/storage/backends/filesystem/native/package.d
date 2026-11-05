module storage.backends.filesystem.native;

version (Windows)
{
    public import storage.backends.filesystem.native.windows : NativeHandle,
        invalidHandle,
        openReadOnly,
        readAt,
        fileLength,
        closeFile;
}
else version (Posix)
{
    public import storage.backends.filesystem.native.posix : NativeHandle,
        invalidHandle,
        openReadOnly,
        readAt,
        fileLength,
        closeFile;
}
else
{
    static assert(false, "Unsupported operating system");
}

version (Have_unit_threaded)
{
    import unit_threaded;
}

@("Native IO preserves its handle across positional binary reads") unittest
{
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-native-\u03b1-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    immutable ubyte[] contents = [0x00, 0x80, 0xFF, 0x01, 0x02];
    write(path, contents);
    auto handle = openReadOnly(path);
    scope (exit)
        closeFile(handle);

    assert(handle != invalidHandle);
    assert(fileLength(handle) == contents.length);
    ubyte[4] destination;
    assert(readAt(handle, 1, destination) == destination.length);
    assert(destination[] == contents[1 .. $]);
    assert(readAt(handle, 0, destination[0 .. 2]) == 2);
    assert(destination[0 .. 2] == contents[0 .. 2]);
    assert(readAt(handle, 0, destination[0 .. 0]) == 0);
    assert(readAt(handle, contents.length, destination) == 0);
    assert(readAt(handle, (1UL << 32) + 1, destination) == 0);
    assert(fileLength(handle) == contents.length);
}

@("Native IO rejects invalid paths and preserves missing-file error codes") unittest
{
    import std.exception : assertThrown;
    import std.file : exists, mkdirRecurse, rmdirRecurse, tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto root = buildPath(tempDir(), "duramen-native-" ~ randomUUID().toString());
    mkdirRecurse(root);
    scope (exit)
        if (root.exists)
            root.rmdirRecurse;

    assertThrown!Exception(openReadOnly(""));
    assertThrown!Exception(openReadOnly(buildPath(root, "file\0ignored")));
    assertThrown!Exception(openReadOnly(root));

    foreach (path; [buildPath(root, "missing.bin"),
            buildPath(root, "missing-parent", "missing.bin")])
    {
        bool missingReported;
        version (Windows)
        {
            import core.sys.windows.windows : ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND;
            import std.windows.syserror : WindowsException;

            try
            {
                auto unexpected = openReadOnly(path);
                closeFile(unexpected);
            }
            catch (WindowsException error)
            {
                missingReported = error.code == ERROR_FILE_NOT_FOUND ||
                    error.code == ERROR_PATH_NOT_FOUND;
            }
        }
        else version (Posix)
        {
            import core.stdc.errno : ENOENT;
            import std.exception : ErrnoException;

            try
            {
                auto unexpected = openReadOnly(path);
                closeFile(unexpected);
            }
            catch (ErrnoException error)
            {
                missingReported = error.errno == ENOENT;
            }
        }
        assert(missingReported);
    }
}

@("Native IO validates handles and ranges without losing a valid handle") unittest
{
    import std.exception : assertThrown;
    import std.file : exists, remove, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    ubyte[2] destination;
    assertThrown!Exception(readAt(invalidHandle, 0, destination));
    assertThrown!Exception(readAt(invalidHandle, 0, destination[0 .. 0]));
    assertThrown!Exception(fileLength(invalidHandle));

    auto path = buildPath(tempDir(), "duramen-native-" ~ randomUUID().toString());
    scope (exit)
        if (path.exists)
            path.remove;

    write(path, "abcd");
    auto handle = openReadOnly(path);
    scope (exit)
        closeFile(handle);

    assertThrown!Exception(readAt(handle, ulong.max, destination));
    assertThrown!Exception(readAt(handle, cast(ulong) long.max + 1, destination));
    assert(readAt(handle, 2, destination) == 2);
    assert(cast(string) destination[] == "cd");
}

@("Native IO allows rename while an opened reader retains its file") unittest
{
    import std.file : exists, remove, rename, tempDir, write;
    import std.path : buildPath;
    import std.uuid : randomUUID;

    auto path = buildPath(tempDir(), "duramen-native-" ~ randomUUID().toString());
    auto renamedPath = path ~ ".renamed";
    scope (exit)
    {
        if (path.exists)
            path.remove;
        if (renamedPath.exists)
            renamedPath.remove;
    }

    write(path, "contents");
    auto handle = openReadOnly(path);
    scope (exit)
        closeFile(handle);

    rename(path, renamedPath);
    ubyte[8] destination;
    assert(readAt(handle, 0, destination) == destination.length);
    assert(cast(string) destination[] == "contents");
    assert(fileLength(handle) == destination.length);
}
