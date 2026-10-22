module storage.config.options;

import std.format : format;
import std.sumtype : SumType;
import storage.revision.revision : DURAMEN_VERSION;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * Default options for the file system storage backend.
 * TODO: redefine `DEFAULT_ROOT_PATH` to change based on the OS.
 */
private const string DEFAULT_ROOT_PATH = format!"C://Program Files/Lignum/v%s/data"(DURAMEN_VERSION);
private const size_t DEFAULT_MAX_OPEN_FILES = 100;
private const bool DEFAULT_USE_DIRECT_IO = true;
private const size_t DEFAULT_DIRECTORY_POOL_SIZE = 2;

struct FileSystemStorageOptions
{
private:
    string _rootPath = DEFAULT_ROOT_PATH;
    size_t _maxOpenFiles = DEFAULT_MAX_OPEN_FILES;
    bool _useDirectIO = DEFAULT_USE_DIRECT_IO;
    size_t _directoryPoolSize = DEFAULT_DIRECTORY_POOL_SIZE;

public:
    @property string rootPath() const
    {
        return _rootPath;
    }

    @property void rootPath(const string rootPath)
    {
        this._rootPath = rootPath;
    }

    @property size_t maxOpenFiles() const
    {
        return _maxOpenFiles;
    }

    @property void maxOpenFiles(const size_t maxOpenFiles)
    {
        this._maxOpenFiles = maxOpenFiles;
    }

    @property bool useDirectIO() const
    {
        return _useDirectIO;
    }

    @property void useDirectIO(const bool useDirectIO)
    {
        this._useDirectIO = useDirectIO;
    }

    @property size_t directoryPoolSize() const
    {
        return _directoryPoolSize;
    }

    @property void directoryPoolSize(const size_t directoryPoolSize)
    {
        this._directoryPoolSize = directoryPoolSize;
    }
}

@("FileSystemStorageOptions exposes defaults and accepts overrides") unittest
{
    FileSystemStorageOptions options;

    assert(options.rootPath == DEFAULT_ROOT_PATH);
    assert(options.maxOpenFiles == DEFAULT_MAX_OPEN_FILES);
    assert(options.useDirectIO == DEFAULT_USE_DIRECT_IO);
    assert(options.directoryPoolSize == DEFAULT_DIRECTORY_POOL_SIZE);

    options.rootPath = "duramen-data";
    options.maxOpenFiles = 256;
    options.useDirectIO = false;
    options.directoryPoolSize = 8;

    assert(options.rootPath == "duramen-data");
    assert(options.maxOpenFiles == 256);
    assert(!options.useDirectIO);
    assert(options.directoryPoolSize == 8);
}

/**
 * Default options for the remote storage backend.
 */
private const size_t DEFAULT_RETRY_COUNT = 5;
private const size_t DEFAULT_REQUEST_TIMEOUT_MS = 3000;

// TODO: refine remote storage.
struct RemoteStorageOptions
{
private:
    string _endpoint;
    size_t _retryCount = DEFAULT_RETRY_COUNT;
    size_t _requestTimeoutMs = DEFAULT_REQUEST_TIMEOUT_MS;

public:
    @property string endpoint() const
    {
        return _endpoint;
    }

    @property void endpoint(const string endpoint)
    {
        this._endpoint = endpoint;
    }

    @property size_t retryCount() const
    {
        return _retryCount;
    }

    @property void retryCount(const size_t retryCount)
    {
        this._retryCount = retryCount;
    }

    @property size_t requestTimeoutMs() const
    {
        return _requestTimeoutMs;
    }

    @property void requestTimeoutMs(const size_t requestTimeoutMs)
    {
        this._requestTimeoutMs = requestTimeoutMs;
    }
}

@("RemoteStorageOptions exposes defaults and accepts overrides") unittest
{
    RemoteStorageOptions options;

    assert(options.endpoint == "");
    assert(options.retryCount == DEFAULT_RETRY_COUNT);
    assert(options.requestTimeoutMs == DEFAULT_REQUEST_TIMEOUT_MS);

    options.endpoint = "https://storage.example.com";
    options.retryCount = 10;
    options.requestTimeoutMs = 5_000;

    assert(options.endpoint == "https://storage.example.com");
    assert(options.retryCount == 10);
    assert(options.requestTimeoutMs == 5_000);
}

// The storage destination can either be a filesystem or remote storage
alias StorageDestinationOptions = SumType!(FileSystemStorageOptions, RemoteStorageOptions);

/** 
 * Types of compression algorithms supported in Duramen
 */
enum CompressionType
{
    NONE,
    LZ4,
    ZSTD,
}

/** 
 * Types of Checksum algorithms supported in Duramen
 */
enum ChecksumType
{
    NONE,
    CRC32C,
}

/**
 * Default options for the storage engine.
 */
private const size_t DEFAULT_WRITE_BUFFER_SIZE = 32 * 1024;
private const size_t DEFAULT_BLOCK_SIZE = 64 * 1024 * 1024;
private const size_t DEFAULT_WAL_SIZE_LIMIT = 64 * 1024 * 1024;

struct StorageEngineOptions
{
private:
    size_t _writeBufferSize = DEFAULT_WRITE_BUFFER_SIZE;

    size_t _blockSize = DEFAULT_BLOCK_SIZE;

    size_t _walSizeLimit = DEFAULT_WAL_SIZE_LIMIT;

    CompressionType _compressionType = CompressionType.NONE;

    ChecksumType _checksumType = ChecksumType.CRC32C;

public:
    @property size_t writeBufferSize() const
    {
        return _writeBufferSize;
    }

    @property void writeBufferSize(const size_t writeBufferSize)
    {
        _writeBufferSize = writeBufferSize;
    }

    @property size_t blockSize() const
    {
        return _blockSize;
    }

    @property void blockSize(const size_t blockSize)
    {
        _blockSize = blockSize;
    }

    @property size_t walSizeLimit() const
    {
        return _walSizeLimit;
    }

    @property void walSizeLimit(const size_t walSizeLimit)
    {
        _walSizeLimit = walSizeLimit;
    }

    @property CompressionType compressionType() const
    {
        return _compressionType;
    }

    @property void compressionType(const CompressionType compressionType)
    {
        _compressionType = compressionType;
    }

    @property ChecksumType checksumType() const
    {
        return _checksumType;
    }

    @property void checksumType(const ChecksumType checksumType)
    {
        _checksumType = checksumType;
    }
}

@("StorageEngineOptions exposes defaults and accepts overrides") unittest
{
    StorageEngineOptions options;

    assert(options.writeBufferSize == DEFAULT_WRITE_BUFFER_SIZE);
    assert(options.blockSize == DEFAULT_BLOCK_SIZE);
    assert(options.walSizeLimit == DEFAULT_WAL_SIZE_LIMIT);
    assert(options.compressionType == CompressionType.NONE);
    assert(options.checksumType == ChecksumType.CRC32C);

    options.writeBufferSize = 64 * 1024;
    options.blockSize = 128 * 1024 * 1024;
    options.walSizeLimit = 128 * 1024 * 1024;
    options.compressionType = CompressionType.LZ4;
    options.checksumType = ChecksumType.NONE;

    assert(options.writeBufferSize == 64 * 1024);
    assert(options.blockSize == 128 * 1024 * 1024);
    assert(options.walSizeLimit == 128 * 1024 * 1024);
    assert(options.compressionType == CompressionType.LZ4);
    assert(options.checksumType == ChecksumType.NONE);
}
