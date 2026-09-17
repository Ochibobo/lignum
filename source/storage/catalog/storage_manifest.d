module storage.catalog.storage_manifest;

import object : hashOf;
import std.container: RedBlackTree;
import std.datetime : Clock, SysTime;
import std.format : format;
import std.path: buildPath;
import std.string : startsWith;
import std.typecons : Nullable;
import storage.types.validation : MaxLength, NotEmpty;

const string DATABASES_HOST_DIR = "../../../databases";
/** 
 * The unique identifier for a database.
 */
struct DatabaseID
{
    private string _value;
    private SysTime _commitTimestamp;

    this(string value)
    {
        _value = value;
        _commitTimestamp = Clock.currTime();
    }

    @property string value() const
    {
        return _value;
    }

    @property SysTime commitTimestamp() const
    {
        return _commitTimestamp;
    }

    string toString() const {
        return format!"DatabaseID: %s, Commit Timestamp: %s"(this._value, this._commitTimestamp);
    }

    bool opEquals(const DatabaseID other) const
    {
        return this._value == other._value;
    }

    size_t toHash() const
    {
        return hashOf(this._value);
    }
}

unittest
{
    auto id1 = DatabaseID("db-123");
    auto id2 = DatabaseID("db-123");
    auto id3 = DatabaseID("db-456");

    assert(id1 == id2);
    assert(!(id1 == id3));
    assert(id1.toHash() == id2.toHash());
    assert(id1.toHash() != id3.toHash());
    assert(id1.value == "db-123");
    assert(id1.commitTimestamp <= Clock.currTime());
    assert(id1.toString.startsWith("DatabaseID: db-123"));
}

/**
 * A database descriptor describes the location and metadata of a database.
 * This is a mutable struct because its metadata can change over time.
 */
struct DatabaseDescriptor
{
    /// The unique identifier of the database.
    private const DatabaseID _id;

    /// The name of the database.
    private @NotEmpty() @MaxLength(128) string _name;

    /// Additional notes about the database.
    private @NotEmpty() @MaxLength(256) string _notes;

    /// The path to the database host directory.
    /// Fullpath = hostPath + name.
    private string _hostPath;

    /// The time when the database was last modified.
    private SysTime _lastModifiedAt;

    @disable this(); // Disable default constructor to enforce initialization of all fields.

    this(DatabaseID id, string name, string notes) {
        this._id = id;
        this._name = name;
        this._notes = notes;
        this._hostPath = buildPath(DATABASES_HOST_DIR, id.value);
        this._lastModifiedAt = Clock.currTime();
    }

    @property DatabaseID id() const { return _id; }
    @property string name() const { return _name; }
    @property void name(const string newName) {
         _name = newName;
        _lastModifiedAt = Clock.currTime();
    }
    @property string notes() const { return _notes; }
    @property void notes(const string newNotes) {
        _notes = newNotes;
        _lastModifiedAt = Clock.currTime();
    }
    @property string hostPath() const { return _hostPath; }
    @property SysTime lastModifiedAt() const { return _lastModifiedAt; }
}

unittest
{
    auto id = DatabaseID("db-123");
    auto descriptor = DatabaseDescriptor(id, "alpha", "initial notes");
    auto expectedHostPath = buildPath(DATABASES_HOST_DIR, id.value);

    assert(descriptor.id == id);
    assert(descriptor.name == "alpha");
    assert(descriptor.notes == "initial notes");
    assert(descriptor.hostPath == expectedHostPath);
    assert(descriptor.lastModifiedAt <= Clock.currTime());

    auto outdatedLastModifiedAt = descriptor.lastModifiedAt;
    descriptor.name = "beta";
    descriptor.notes = "updated notes";

    assert(descriptor.name == "beta");
    assert(descriptor.notes == "updated notes");
    assert(descriptor.hostPath == expectedHostPath);
    assert(outdatedLastModifiedAt <= descriptor.lastModifiedAt);
    static assert(!__traits(compiles, DatabaseDescriptor()));
}

/**
*   A storage manifest describes the @Unique() location and properties of the databases on disk.
*   It contains metadata about all databases reachable via the file paths.
*/
final class StorageManifest
{
    private static StorageManifest _instance;
    private RedBlackTree!string _databaseIDIndex;
    private RedBlackTree!string _databaseNameIndex;
    private DatabaseDescriptor[] _databases;

    private this() {}

    static StorageManifest getInstance()
    {
        if (_instance is null)
        {
            _instance = new StorageManifest();
        }
        return _instance;
    }

    @property DatabaseDescriptor[] databases() { return _databases.dup; }

    void addDatabase(const DatabaseDescriptor descriptor) {}

    void updateDatabase(const DatabaseDescriptor descriptor) {}

    Nullable!DatabaseDescriptor getDatabase(const DatabaseID id) const { return Nullable!DatabaseDescriptor.init; }

    Nullable!DatabaseDescriptor getDatabaseByName(const string name) const { return Nullable!DatabaseDescriptor.init; }

    bool contains(const DatabaseDescriptor descriptor) const { return false; }

    bool removeDatabase(const DatabaseID id){ return false; }

    // TODO: tabular string format.
    override string toString() const{ return ""; }
}
