module storage.io.reader;

/**
 * Reader interface specification.
 */
interface RandomAccessReader
{

    /**
     * Reads bytes starting at the supplied offset. Concurrent calls must use
     * independent destination buffers.
     *
     * ### Parameters
     *   * `offset`: The offset to start reading from.
     *   * `destination`: The sized buffer to write the bytes into.
     *
     * ### Returns
     *   * The number of bytes read. Zero indicates `EOF` for a nonempty buffer.
     */
    size_t readAt(ulong offset, scope ubyte[] destination) shared;

    /**
     * Returns the total stored object or file length.
     */
    ulong length() shared;

    /**
     * Releases the underlying file or remote resource.
     * The owner must finish all operations before closing the reader.
     */
    void close() shared;
}
