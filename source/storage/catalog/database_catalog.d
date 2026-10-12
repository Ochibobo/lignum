module storage.catalog.database_catalog;

import object : hashOf;
import std.container : RedBlackTree;
import std.datetime : Clock, SysTime;
import std.format : format;
import std.path : buildPath;
import std.string : startsWith;
import std.sumtype : SumType, match;
import std.typecons : Nullable;
import std.variant : Variant;
import storage.types.validation : MaxLength, NotEmpty;

version (Have_unit_threaded)
{
    import unit_threaded;
}
else
{
    enum Serial
    {
        fallback,
    }
}

const string DATABASES_HOST_DIR = "../../../databases";

/** 
 * A marker for a database state.
 */
enum StorageState
{
    ACTIVE,
    MARKED_FOR_DELETION,
}

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

    string toString() const
    {
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

@("DatabaseID compares and hashes by value") unittest
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
    private DatabaseID _id;

    /// The name of the database.
    private @NotEmpty() @MaxLength(128) string _name;

    /// Additional notes about the database.
    private @NotEmpty() @MaxLength(256) string _notes;

    /// The path to the database host directory.
    /// Fullpath = hostPath + name.
    private string _hostPath;

    /// The time when the database was last modified.
    private SysTime _lastModifiedAt;

    // Whether the database represented by this descriptor is active or not
    private StorageState _storageState;

    @disable this(); // Disable default constructor to enforce initialization of all fields.

    this(DatabaseID id, string name, string notes)
    {
        this._id = id;
        this._name = name;
        this._notes = notes;
        this._hostPath = buildPath(DATABASES_HOST_DIR, id.value);
        this._lastModifiedAt = Clock.currTime();
        this._storageState = StorageState.ACTIVE;
    }

    @property const(DatabaseID) id() const
    {
        return _id;
    }

    @property string name() const
    {
        return _name;
    }

    @property void name(const string newName)
    {
        _name = newName;
        _lastModifiedAt = Clock.currTime();
    }

    @property string notes() const
    {
        return _notes;
    }

    @property void notes(const string newNotes)
    {
        _notes = newNotes;
        _lastModifiedAt = Clock.currTime();
    }

    @property string hostPath() const
    {
        return _hostPath;
    }

    @property SysTime lastModifiedAt() const
    {
        return _lastModifiedAt;
    }

    @property StorageState storageState() const
    {
        return _storageState;
    }

    void markForDeletion()
    {
        _storageState = StorageState.MARKED_FOR_DELETION;
        _lastModifiedAt = Clock.currTime();
    }

    void markAsActive()
    {
        _storageState = StorageState.ACTIVE;
        _lastModifiedAt = Clock.currTime();
    }
}

@("DatabaseDescriptor initializes and updates metadata") unittest
{
    auto id = DatabaseID("db-123");
    auto descriptor = DatabaseDescriptor(id, "alpha", "initial notes");
    auto expectedHostPath = buildPath(DATABASES_HOST_DIR, id.value);

    assert(descriptor.id == id);
    assert(descriptor.name == "alpha");
    assert(descriptor.notes == "initial notes");
    assert(descriptor.hostPath == expectedHostPath);
    assert(descriptor.lastModifiedAt <= Clock.currTime());
    assert(descriptor.storageState == StorageState.ACTIVE);

    descriptor.markForDeletion();
    assert(descriptor.storageState == StorageState.MARKED_FOR_DELETION);

    descriptor.markAsActive();
    assert(descriptor.storageState == StorageState.ACTIVE);

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
 * DatabaseDescriptors have a different disk representation, depending on whether
 * an entry in the catalog is a snapshot of the entire descriptor or just a delta.
 */

/**
 * Contains the entire payload of the DatabaseDescriptor.
 */
struct DatabaseDescriptorSnapshot
{
    private DatabaseDescriptor _databaseDescriptor;

    @disable this();

    this(DatabaseDescriptor databaseDescriptor)
    {
        this._databaseDescriptor = databaseDescriptor;
    }

    @property DatabaseDescriptor databaseDescriptor() const
    {
        return this._databaseDescriptor;
    }

    // TODO: fallsback to the DatabaseDescriptor toString()
    string toString() const
    {
        return "";
    }
}

/**
 * Set of actions associated with updating a DatabaseDescriptor.
 */
enum DatabaseDescriptorUpdateAction
{
    UPDATE,
    DELETE,
}

/** 
 * Description of the field payload used in the delta operation.
 */
struct DatabaseDescriptorDeltaFieldDefinition
{
    private string _fieldName;
    private Variant _fieldValue;

    @disable this();

    this(const string fieldName, const Variant fieldValue)
    {
        this._fieldName = fieldName;
        this._fieldValue = fieldValue;
    }

    @property string fieldName() const
    {
        return this._fieldName;
    }

    @property Variant fieldValue() const
    {
        return this._fieldValue;
    }

    TypeInfo fieldType() const
    {
        return this._fieldValue.type;
    }

    // TODO: implement toString
    string toString() const
    {
        return "";
    }
}

/** 
 * The entire Delta payload, consisting of the action & the field definition.
 */
struct DatabaseDescriptorDeltaPayload
{
    private DatabaseDescriptorUpdateAction _action;
    private Nullable!DatabaseDescriptorDeltaFieldDefinition _deltaFieldDefinition;

    @disable this();

    this(const DatabaseDescriptorUpdateAction action,
        const Nullable!DatabaseDescriptorDeltaFieldDefinition deltaFieldDefinition)
    {
        this._action = action;
        this._deltaFieldDefinition = deltaFieldDefinition;
    }

    @property DatabaseDescriptorUpdateAction action() const
    {
        return this._action;
    }

    @property Nullable!DatabaseDescriptorDeltaFieldDefinition deltaFieldDefinition() const
    {
        return this._deltaFieldDefinition;
    }
}

/** 
 * Contains a delta of the DatabaseDescriptor.
 * It is used for efficient updates and storage.
 * Instead of storing a replica of the entire descriptor upon updates,
 * we only store the `UpdatePayload` of the descriptor.
 *
 * `Duramen` is an immutable store, so updates are not supported.
 *
 * This is then re-built when the we load the descriptors in memory.
 */
struct DatabaseDescriptorDelta
{
    private DatabaseID _databaseID;
    private DatabaseDescriptorDeltaPayload _payload;

    @disable this();

    this(const DatabaseID databaseID, const DatabaseDescriptorDeltaPayload payload)
    {
        this._databaseID = databaseID;
        this._payload = payload;
    }

    @property DatabaseID databaseID() const
    {
        return this._databaseID;
    }

    @property DatabaseDescriptorDeltaPayload payload() const
    {
        return this._payload;
    }

    // TODO: implement toString!
    string toString() const
    {
        return "";
    }
}

/** 
 * An entry in the DatabaseCatalog can either be a `DatabaseDescriptorSnapshot`
 * or a `DatabaseDescriptorDelta`.
 * This `CatalogEntry` is a `Union` of both.
 */
alias CatalogEntry = SumType!(DatabaseDescriptorSnapshot, DatabaseDescriptorDelta);

@("Catalog entries represent snapshots and deltas") unittest
{
    auto id = DatabaseID("db-123");
    auto descriptor = DatabaseDescriptor(id, "alpha", "initial notes");
    auto snapshot = DatabaseDescriptorSnapshot(descriptor);
    CatalogEntry snapshotEntry = snapshot;

    assert(snapshot.databaseDescriptor.id == id);
    assert(snapshot.databaseDescriptor.name == "alpha");
    assert(snapshotEntry.match!(
            (ref DatabaseDescriptorSnapshot storedSnapshot) => true,
            (ref DatabaseDescriptorDelta storedDelta) => false,
    ));

    Variant fieldValue = "updated notes";
    auto fieldDefinition = DatabaseDescriptorDeltaFieldDefinition("notes", fieldValue);
    Nullable!DatabaseDescriptorDeltaFieldDefinition nullableFieldDefinition = fieldDefinition;
    auto payload = DatabaseDescriptorDeltaPayload(
        DatabaseDescriptorUpdateAction.UPDATE,
        nullableFieldDefinition,
    );
    auto delta = DatabaseDescriptorDelta(id, payload);
    CatalogEntry deltaEntry = delta;

    assert(delta.databaseID == id);
    assert(delta.payload.action == DatabaseDescriptorUpdateAction.UPDATE);
    assert(!delta.payload.deltaFieldDefinition.isNull);
    assert(delta.payload.deltaFieldDefinition.get.fieldName == "notes");
    assert(delta.payload.deltaFieldDefinition.get.fieldType == typeid(string));
    assert(delta.payload.deltaFieldDefinition.get.fieldValue.get!string == "updated notes");
    assert(deltaEntry.match!(
            (ref DatabaseDescriptorSnapshot storedSnapshot) => false,
            (ref DatabaseDescriptorDelta storedDelta) => true,
    ));

    auto deletePayload = DatabaseDescriptorDeltaPayload(
        DatabaseDescriptorUpdateAction.DELETE,
        Nullable!DatabaseDescriptorDeltaFieldDefinition.init,
    );
    auto deleteDelta = DatabaseDescriptorDelta(id, deletePayload);

    assert(deleteDelta.payload.action == DatabaseDescriptorUpdateAction.DELETE);
    assert(deleteDelta.payload.deltaFieldDefinition.isNull);

    static assert(!__traits(compiles, DatabaseDescriptorSnapshot()));
    static assert(!__traits(compiles, DatabaseDescriptorDeltaFieldDefinition()));
    static assert(!__traits(compiles, DatabaseDescriptorDeltaPayload()));
    static assert(!__traits(compiles, DatabaseDescriptorDelta()));
}

/**
*   A database catalog describes the @Unique() location and properties of the databases on disk.
*   It contains metadata about all databases reachable via the file paths.
*/
final class DatabaseCatalog
{
    private static DatabaseCatalog _instance;
    private DatabaseDescriptor[DatabaseID] _databaseByID;
    private DatabaseID[string] _databaseIDByName;
    private CatalogEntry[] _entries;

    private this()
    {
    }

    static DatabaseCatalog getInstance()
    {
        if (_instance is null)
        {
            _instance = new DatabaseCatalog();
        }
        return _instance;
    }

    @property const(CatalogEntry)[] entries() const
    {
        return _entries;
    }

    void addEntry(const CatalogEntry entry)
    {
        // Build the descriptor via applying the entry
        this.applyEntry(entry);
        _entries ~= entry;
    }

    void applyEntry(const CatalogEntry entry)
    {
        auto descriptor = entry.match!(
            (const ref DatabaseDescriptorSnapshot snapshot) => applySnapshot(snapshot),
            (const ref DatabaseDescriptorDelta delta) => applyDelta(delta),
        );

        _databaseByID[descriptor.id] = descriptor;
        _databaseIDByName[descriptor.name] = descriptor.id;
    }

    private ref const(DatabaseDescriptor) applySnapshot(const DatabaseDescriptorSnapshot snapshot)
    {
        // This will introduce a snapshot entry in the catalog.
        // 
        return *new DatabaseDescriptor(DatabaseID(""), "", "");
    }

    private ref const(DatabaseDescriptor) applyDelta(const DatabaseDescriptorDelta delta)
    {
        // This will update the descriptor in the catalog.
        // TODO: replace with actual implementation.
        return *new DatabaseDescriptor(DatabaseID(""), "", "");
    }

    void logEntries() const
    {
        foreach (const CatalogEntry entry; _entries)
        {
            // Log Entries as is.
        }
    }

    void logEntries(const DatabaseID id) const
    {
        // Log entries associated to a databaseID
    }

    Nullable!DatabaseDescriptor getDatabase(const DatabaseID id) const
    {
        return Nullable!DatabaseDescriptor.init;
    }

    Nullable!DatabaseDescriptor getDatabaseByName(const string name) const
    {
        return Nullable!DatabaseDescriptor.init;
    }

    bool contains(const DatabaseDescriptor descriptor) const
    {
        return false;
    }

    // TODO: tabular string format.
    override string toString() const
    {
        return "";
    }
}

@Serial
@("DatabaseCatalog stores snapshot and delta entries") unittest
{
    auto catalog = DatabaseCatalog.getInstance();
    auto initialEntryCount = catalog.entries.length;
    auto id = DatabaseID("db-catalog-entry");
    auto descriptor = DatabaseDescriptor(id, "catalog entry", "snapshot notes");
    CatalogEntry snapshotEntry = DatabaseDescriptorSnapshot(descriptor);
    Variant fieldValue = "updated notes";
    auto fieldDefinition = DatabaseDescriptorDeltaFieldDefinition("notes", fieldValue);
    Nullable!DatabaseDescriptorDeltaFieldDefinition nullableFieldDefinition = fieldDefinition;
    auto payload = DatabaseDescriptorDeltaPayload(
        DatabaseDescriptorUpdateAction.UPDATE,
        nullableFieldDefinition,
    );
    CatalogEntry deltaEntry = DatabaseDescriptorDelta(id, payload);

    catalog.addEntry(snapshotEntry);
    catalog.addEntry(deltaEntry);

    assert(catalog.entries.length == initialEntryCount + 2);
}
