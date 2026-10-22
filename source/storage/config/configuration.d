module storage.config.configuration;

import storage.config.options : StorageEngineOptions;

struct StorageConfiguration
{
    enum uint CURRENT_VERSION = 1;
    StorageEngineOptions storageEngineOptions;

    this(const StorageEngineOptions storageEngineOptions)
    {
        this.storageEngineOptions = storageEngineOptions;
    }

    static StorageConfiguration getDefaultConfiguration()
    {
        return StorageConfiguration(StorageEngineOptions());
    }
}
