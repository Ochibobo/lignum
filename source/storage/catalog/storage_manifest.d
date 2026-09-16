module storage.catalog.storage_manifest;

import std.datetime : Clock, SysTime;
import std.format : format;
import std.string : indexOf;
import storage.types.validation : MaxLength, NotEmpty;

/** 
 * The unique identifier for a database.
 */
struct DatabaseID
{
    private string _value;
    private SysTime commitTimestamp;

    this(string value)
    {
        _value = value;
        commitTimestamp = Clock.currTime();
    }

    string value() const
    {
        return _value;
    }

    SysTime getCommitTimestamp() const
    {
        return commitTimestamp;
    }

    string toString() const {
        return format!"DatabaseID: %s, Commit Timestamp: %s"(this._value, this.commitTimestamp);
    }
}

unittest
{
    auto id = DatabaseID("db-123");

    assert(id.value == "db-123");
    assert(id.getCommitTimestamp() <= Clock.currTime());
    assert(id.toString.indexOf("DatabaseID:") == 0);
    assert(id.toString.indexOf("db-123") > 0);
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
*   A storage manifest describes the @Unique() location and properties of the databases on disk.
*   It contains metadata about all databases reachable via the file paths.
*/
struct StorageManifest
{

}
