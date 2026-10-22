module storage.backends.backend;

import storage.io.reader : StorageReader;
import storage.io.writer : StorageWriter;

/**
 * Interface definition for Duramen storage backends
 */
interface StorageBackend
{
    /**
     * Reads the complete contents of a stored object.
     *
     * Params:
     *   `key` - backend-relative key identifying the object.
     *
     * Returns:
     *   The complete contents of the object.
     */
    ubyte[] readObject(string key);

    /**
     * Atomically replaces the complete contents of a stored object.
     *
     * Readers must observe either the previous complete contents or the new
     * complete contents, never a partially written object.
     *
     * Params:
     *   `key` - backend-relative key identifying the object.
     *   `contents` - complete replacement contents of the object.
     */
    void replaceObject(string key, scope const(ubyte)[] contents);

    /**
     * Determines whether a stored object exists.
     *
     * Params:
     *   `key` - backend-relative key identifying the object.
     *
     * Returns:
     *   `true` when the object exists; otherwise, `false`.
     */
    bool exists(string key);

    /**
     * Open a file for reading.
     *
     * Params:
     *   `fileName` - name of the file to open.
     *
     * Returns:
     *   `StorageReader` for the file.
     */
    StorageReader openForRead(string fileName);

    /**
     * Open a file for writing.
     *
     * Params:
     *   `fileName` - name of the file to open.
     *
     * Returns:
     *   `StorageWriter` for the file.
     */
    StorageWriter openForWrite(string fileName);

    /**
     * Open a file for appending.
     *
     * Params:
     *   `fileName` - name of the file to open.
     *
     * Returns:
     *   `StorageWriter` for the file.
     */
    StorageWriter openForAppend(string fileName);
}
