module storage.backends.filesystem.native.posix;

version (Posix)
{
    import core.stdc.errno : errno, EINTR;
    import core.sys.posix.fcntl : open, O_RDONLY, O_CLOEXEC;
    import core.sys.posix.sys.stat : fstat, stat_t, S_ISREG;
    import core.sys.posix.sys.types : off_t, ssize_t;
    import core.sys.posix.unistd : pread, posixClose = close;

    import std.algorithm.searching : canFind;
    import std.exception : enforce, ErrnoException;
    import std.string : toStringz;

    alias NativeHandle = int;
    enum NativeHandle invalidHandle = -1;

    /**
     * Open the file to read from and return its descriptor.
     */
    NativeHandle openReadOnly(string path)
    {
        // Reject embedded null characters as POSIX path functions use
        // null-terminated strings.
        enforce(path.length != 0 && !path.canFind("\0"),
            "Invalid file path");

        // Convert the path into a null-terminated string pointer (suitable for C APIs)
        auto filePath = toStringz(path);

        NativeHandle fileDescriptor;

        do
            fileDescriptor = open(filePath, O_RDONLY | O_CLOEXEC);
        // retry an interrupted opening attempt if interrupted by a caught OS signal.
        while (fileDescriptor < 0 && errno == EINTR);

        if (fileDescriptor < 0)
        {
            const error = errno;
            throw new ErrnoException("Cannot open: " ~ path, error);
        }

        scope (failure)
        {
            posixClose(fileDescriptor);
        }

        stat_t info;

        if (fstat(fileDescriptor, &info) != 0)
        {
            const error = errno;
            throw new ErrnoException("Cannot inspect: " ~ path, error);
        }

        enforce(S_ISREG(info.st_mode), "Expected a regular file: " ~ path);

        return fileDescriptor;
    }

    /**
     * Read from a particular offset.
     */
    size_t readAt(
        NativeHandle descriptor,
        ulong offset,
        scope ubyte[] destination)
    {
        enforce(descriptor != invalidHandle, "Reader is closed");
        enforce(offset <= cast(ulong) off_t.max, "Offset is out of range");
        enforce(destination.length <= ulong.max - offset, "Read range overflow");

        if (destination.length == 0)
        {
            return 0;
        }

        const requestedBytesSize = destination.length > cast(size_t) ssize_t.max
            ? cast(size_t) ssize_t.max : destination.length;

        ssize_t count;

        do
            count = pread(
                descriptor,
                destination.ptr,
                requestedBytesSize,
                cast(off_t) offset);
        while (count < 0 && errno == EINTR);

        if (count < 0)
        {
            const error = errno;
            throw new ErrnoException("pread failed", error);
        }

        return cast(size_t) count;
    }

    ulong fileLength(NativeHandle descriptor)
    {
        enforce(descriptor != invalidHandle, "Reader is closed");

        stat_t info;

        if (fstat(descriptor, &info) != 0)
        {
            const error = errno;
            throw new ErrnoException("fstat failed", error);
        }

        enforce(info.st_size >= 0, "Invalid file size");

        return cast(ulong) info.st_size;
    }

    void closeFile(NativeHandle descriptor)
    {
        if (posixClose(descriptor) != 0)
        {
            const error = errno;
            throw new ErrnoException("close failed", error);
        }
    }
}
