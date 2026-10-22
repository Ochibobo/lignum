module storage.config.configuration_manager;

import std.string : representation;
import storage.backends.backend : StorageBackend;
import storage.config.codec : StorageConfigurationCodec;
import storage.config.configuration : StorageConfiguration;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * Loads and stores storage configuration files.
 */
struct ConfigurationManager
{
    private enum string OPTIONS_KEY = "OPTIONS.toml";

    static StorageConfiguration load(StorageBackend backend)
    {
        auto contents = backend.readObject(OPTIONS_KEY);
        return StorageConfigurationCodec.decode(cast(const(char)[]) contents);
    }

    static void store(StorageBackend backend, const StorageConfiguration configuration)
    {
        string content = StorageConfigurationCodec.encode(configuration);
        backend.replaceObject(OPTIONS_KEY, content.representation);
    }
}

@("ConfigurationManager stores and loads an options file") unittest
{
    import std.file : exists, rmdirRecurse, tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;
    import storage.backends.filesystem.backend : FileSystemBackend;
    import storage.config.options : FileSystemStorageOptions;

    auto rootPath = buildPath(tempDir(), "duramen-options-" ~ randomUUID().toString());
    scope (exit)
    {
        if (rootPath.exists)
            rootPath.rmdirRecurse;
    }

    FileSystemStorageOptions backendOptions;
    backendOptions.rootPath = rootPath;
    StorageBackend backend = new FileSystemBackend(backendOptions);
    auto expected = StorageConfiguration.getDefaultConfiguration();
    ConfigurationManager.store(backend, expected);

    assert(buildPath(rootPath, "OPTIONS.toml").exists);

    auto actual = ConfigurationManager.load(backend);

    assert(actual.storageEngineOptions.writeBufferSize == expected.storageEngineOptions.writeBufferSize);
    assert(actual.storageEngineOptions.blockSize == expected.storageEngineOptions.blockSize);
    assert(actual.storageEngineOptions.walSizeLimit == expected.storageEngineOptions.walSizeLimit);
    assert(actual.storageEngineOptions.compressionType == expected.storageEngineOptions.compressionType);
    assert(actual.storageEngineOptions.checksumType == expected.storageEngineOptions.checksumType);
}
