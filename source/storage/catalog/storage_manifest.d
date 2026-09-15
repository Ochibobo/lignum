module storage.catalog.storage_manifest;

import std.datetime : SysTime;
import std.uuid : UUID;
import storage.types.validation : MaxLength, NotEmpty;

/** 
 * The unique identifier for a database.
 */
struct DatabaseID(T)
{
    private T _value;

    this(T value)
    {
        _value = value;
    }

    @property
    T value() const
    {
        return _value;
    }
}

/**
 * A database descriptor describes the location and metadata of a database.
 * This is a mutable struct because its metadata can change over time.
 */
struct DatabaseDescriptor
{
    /// The unique identifier of the database.
    DatabaseID id;

    /// The name of the database.
    @NotEmpty() @MaxLength(128) string name;

    /// Additional notes about the database.
    @NotEmpty() @MaxLength(256) string notes;

    /// The path to the database host directory.
    /// Fullpath = hostPath + name.
    string hostPath;

    /// The time when the database was created.
    SysTime createdAt;

    /// The time when the database was last modified.
    SysTime lastModifiedAt;
}

/**
*   A storage manifest describes the     @Unique() location and properties of the databases on disk.
*   It contains metadata about all databases reachable via the file paths.
*/
struct StorageManifest
{

}
