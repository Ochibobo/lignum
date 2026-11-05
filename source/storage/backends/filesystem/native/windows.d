module storage.backends.filesystem.native.windows;

version (Windows)
{
    import core.sys.windows.windows : DWORD,
        ERROR_HANDLE_EOF, ERROR_IO_PENDING,
        GENERIC_READ, FALSE,
        FILE_FLAG_OVERLAPPED,
        FILE_SHARE_DELETE, FILE_SHARE_READ, FILE_SHARE_WRITE,
        FILE_TYPE_DISK, HANDLE, INVALID_HANDLE_VALUE,
        LARGE_INTEGER,
        OPEN_EXISTING,
        OVERLAPPED,
        TRUE,
        CloseHandle, CreateEventW, CreateFileW, GetFileSizeEx,
        GetLastError, GetFileType,
        GetOverlappedResult,
        ReadFile;

    import std.algorithm.searching : canFind;
    import std.exception : enforce;
    import std.utf : toUTF16z;
    import std.windows.syserror : WindowsException;

    alias NativeHandle = HANDLE;
    enum NativeHandle invalidHandle = INVALID_HANDLE_VALUE;

    NativeHandle openReadOnly(string path)
    {
        enforce(path.length != 0 && !path.canFind("\0"),
            "Invalid file path");

        auto handle = CreateFileW(
            toUTF16z(path),
            GENERIC_READ,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            null,
            OPEN_EXISTING,
            FILE_FLAG_OVERLAPPED,
            null,
        );

        if (handle == invalidHandle)
        {
            const error = GetLastError();
            throw new WindowsException(error, "Cannot open: " ~ path);
        }

        scope (failure)
        {
            CloseHandle(handle);
        }

        enforce(GetFileType(handle) == FILE_TYPE_DISK,
            "Expected a disk file: " ~ path);

        return handle;
    }

    size_t readAt(
        NativeHandle handle,
        ulong offset,
        scope ubyte[] destination,
    )
    {
        enforce(handle != invalidHandle, "Reader is closed");
        enforce(offset <= cast(ulong) long.max, "Offset is out of range");
        enforce(destination.length <= ulong.max - offset, "Read range overflow");

        if (destination.length == 0)
        {
            return 0;
        }

        auto event = CreateEventW(null, TRUE, FALSE, null);

        if (event is null)
        {
            const error = GetLastError();
            throw new WindowsException(error, "CreateEventW failed");
        }

        scope (exit)
        {
            CloseHandle(event);
        }

        OVERLAPPED request;
        request.Offset = cast(DWORD) offset;
        request.OffsetHigh = cast(DWORD)(offset >> 32);
        request.hEvent = event;

        const requestedBytesSize = destination.length > DWORD.max
            ? DWORD.max
            : cast(DWORD) destination.length;

        if (!ReadFile(handle,
                destination.ptr,
                requestedBytesSize,
                null,
                &request))
        {
            const error = GetLastError();

            if (error == ERROR_HANDLE_EOF)
            {
                return 0;
            }

            if (error != ERROR_IO_PENDING)
            {
                throw new WindowsException(error, "ReadFile failed");
            }
        }

        DWORD count;

        if (!GetOverlappedResult(handle, &request, &count, TRUE))
        {
            const error = GetLastError();

            if (error == ERROR_HANDLE_EOF)
            {
                return 0;
            }

            throw new WindowsException(error, "GetOverlappedResult failed");
        }

        return count;
    }

    ulong fileLength(NativeHandle handle)
    {
        enforce(handle != invalidHandle, "Reader is closed");

        LARGE_INTEGER size;

        if (!GetFileSizeEx(handle, &size))
        {
            const error = GetLastError();
            throw new WindowsException(error, "GetFileSizeEx failed");
        }

        enforce(size.QuadPart >= 0, "Invalid file size");

        return cast(ulong) size.QuadPart;
    }

    void closeFile(NativeHandle handle)
    {
        if (!CloseHandle(handle))
        {
            const error = GetLastError();
            throw new WindowsException(error, "CloseHandle failed");
        }
    }
}
