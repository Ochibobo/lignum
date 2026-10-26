module storage.io.writer;

/**
 * Sequential single-owner writer interface specification.
 *
 * Instances are not thread-safe. Callers must ensure that a writer is
 * accessed by only one thread at a time.
 */
interface StorageWriter
{
    /**
     * Writes the complete byte sequence.
     *
     * The behavior depends on how the writer was opened:
     *   * `openForWrite`: Replaces/writes content;
     *   * `openForAppend`: Adds content at the end.
     *
     * ### Parameters
     *   * `data`: The byte sequence to write.
     */
    void write(in ubyte[] data);

    /**
     * Pushes language/runtime buffers to the operating system
     * or remote transport.
     */
    void flush();

    /**
     * Requests durable persistence before returning.
     */
    void sync();

    /**
     * Releases the underlying file or remote resource.
     */
    void close();
}
