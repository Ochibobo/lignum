module storage.config.codec;

import std.conv : to;
import storage.config.configuration : StorageConfiguration;
import storage.config.options;
import toml : parseTOML, TOMLValue;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * Encodes and decodes storage engine options.
 */
package struct StorageEngineOptionsCodec
{
    static string encode(const StorageEngineOptions options)
    {
        string contents;

        appendAssignment(contents, "write_buffer_size", cast(long) options.writeBufferSize);
        appendAssignment(contents, "block_size", cast(long) options.blockSize);
        appendAssignment(contents, "wal_size_limit", cast(long) options.walSizeLimit);
        appendAssignment(contents, "compression", options.compressionType.to!string);
        appendAssignment(contents, "checksum", options.checksumType.to!string);

        return contents;
    }

    static StorageEngineOptions decode(const TOMLValue[string] document)
    {
        StorageEngineOptions options;

        options.writeBufferSize = cast(size_t) document["write_buffer_size"].integer;
        options.blockSize = cast(size_t) document["block_size"].integer;
        options.walSizeLimit = cast(size_t) document["wal_size_limit"].integer;
        options.compressionType = document["compression"].str.to!CompressionType;
        options.checksumType = document["checksum"].str.to!ChecksumType;

        return options;
    }
}

/**
 * Coordinates encoding and decoding of complete storage configurations.
 */
package struct StorageConfigurationCodec
{
    static string encode(const StorageConfiguration configuration)
    {
        string contents;

        appendAssignment(contents, "format_version", cast(long) configuration.CURRENT_VERSION);
        contents ~= "\n[engine]\n";
        contents ~= StorageEngineOptionsCodec.encode(configuration.storageEngineOptions);

        return contents;
    }

    static StorageConfiguration decode(scope const(char)[] contents)
    {
        auto document = parseTOML(contents);
        auto engine = StorageEngineOptionsCodec.decode(document["engine"].table);
        return StorageConfiguration(engine);
    }
}

private void appendAssignment(T)(ref string contents, const string key, T value)
{
    contents ~= key ~ " = " ~ TOMLValue(value).toString() ~ "\n";
}

@("Storage configuration codecs round-trip engine options") unittest
{
    StorageEngineOptions engine;
    engine.writeBufferSize = 64 * 1024;
    engine.blockSize = 128 * 1024;
    engine.walSizeLimit = 256 * 1024;
    engine.compressionType = CompressionType.LZ4;
    engine.checksumType = ChecksumType.NONE;

    auto encoded = StorageConfigurationCodec.encode(StorageConfiguration(engine));

    import std.algorithm.searching : canFind;
    assert(encoded.canFind("[engine]"));
    assert(!encoded.canFind("[destination]"));
    assert(!encoded.canFind("root_path"));
    assert(!encoded.canFind("{"));

    auto decoded = StorageConfigurationCodec.decode(encoded);

    assert(decoded.storageEngineOptions.writeBufferSize == engine.writeBufferSize);
    assert(decoded.storageEngineOptions.blockSize == engine.blockSize);
    assert(decoded.storageEngineOptions.walSizeLimit == engine.walSizeLimit);
    assert(decoded.storageEngineOptions.compressionType == engine.compressionType);
    assert(decoded.storageEngineOptions.checksumType == engine.checksumType);

}
