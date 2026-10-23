module storage.io.reader;

/**
 * Reader interface specification.
 */
interface StorageReader
{
    /**
     * Reads up to `length` bytes from the current position.
     *
     * ### Parameters
     *   * `destination`: The sized buffer to write the bytes into.
     *
     * ### Returns
     *   * The number of bytes read. Zero indicates `EOF`
     */
    size_t read(scope ubyte[] destination);

    /**
     * Reads bytes starting at the supplied offset without changing
     * the reader's current position.
     *
     * ### Parameters
     *   * `offset`: The offset to start reading from.
     *   * `destination`: The sized buffer to write the bytes into.
     *
     * ### Returns
     *   * The number of bytes read. Zero indicates `EOF`
     */
    size_t readAt(ulong offset, scope ubyte[] destination);

    /**
     * Returns the total stored object or file length.
     */
    ulong length();

    /**
     * Releases the underlying file or remote resource.
     */
    void close();
}
