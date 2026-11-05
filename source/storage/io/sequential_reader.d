module storage.io.sequential_reader;

import core.atomic : atomicLoad;
import std.exception : enforce;

import storage.io.reader : RandomAccessReader;

/**
 * A concrete implementation of a SequentialAccessReader that's essentially a wrapper 
 * around a RandomAccessReader with position stored as state.
 */
struct SequentialAccessReader
{

private:
    shared(RandomAccessReader) _reader;
    ulong _position = 0;

public:
    this(shared(RandomAccessReader) reader, const ulong startPosition = 0)
    {
        enforce(reader !is null, "reader cannot be null");
        this._reader = atomicLoad(reader);
        this._position = startPosition;
    }

    size_t read(scope ubyte[] buffer)
    {
        enforce(_reader !is null, "reader cannot be null");
        enforce(buffer.length <= ulong.max - _position, "Read range overflow");
        const bytesRead = this._reader.readAt(this._position, buffer);

        this._position += bytesRead;

        return bytesRead;
    }

    ulong position() const
    {
        return this._position;
    }
}

version (Have_unit_threaded)
{
    import unit_threaded;
}

version (unittest)
{
    import core.atomic : atomicStore;
    import std.algorithm.comparison : min;

    private final class TestRandomAccessReader : RandomAccessReader
    {
        private immutable string _contents;
        private size_t _readLimit;
        private immutable bool _failReads;
        private bool _closed;

        this(string contents, size_t readLimit = size_t.max, bool failReads = false) shared
        {
            _contents = contents;
            atomicStore(_readLimit, readLimit);
            _failReads = failReads;
        }

        override size_t readAt(ulong offset, scope ubyte[] destination) shared
        {
            enforce(!atomicLoad(_closed), "Reader is closed");
            enforce(!_failReads, "Injected read failure");
            if (offset >= _contents.length)
                return 0;

            const start = cast(size_t) offset;
            const readLimit = atomicLoad(_readLimit);
            const count = min(destination.length, readLimit, _contents.length - start);
            destination[0 .. count] = cast(const(ubyte)[]) _contents[start .. start + count];
            return count;
        }

        override ulong length() shared
        {
            enforce(!atomicLoad(_closed), "Reader is closed");
            return _contents.length;
        }

        override void close() shared
        {
            atomicStore(_closed, true);
        }
    }
}

@("SequentialAccessReader advances by actual byte counts from its start offset") unittest
{
    auto source = new shared TestRandomAccessReader("abcdefghij");
    scope (exit)
        source.close();

    auto reader = SequentialAccessReader(atomicLoad(source), 2);
    ubyte[3] first;
    ubyte[3] second;

    assert(reader.position == 2);
    assert(reader.read(first) == 3);
    assert(cast(string) first[] == "cde");
    assert(reader.position == 5);
    assert(reader.read(second) == 3);
    assert(cast(string) second[] == "fgh");
    assert(reader.position == 8);
}

@("SequentialAccessReader preserves its position on empty reads and EOF") unittest
{
    auto source = new shared TestRandomAccessReader("abc");
    scope (exit)
        source.close();

    auto reader = SequentialAccessReader(atomicLoad(source));
    ubyte[5] destination;
    destination[] = 0x55;

    assert(reader.read(destination[0 .. 0]) == 0);
    assert(reader.position == 0);
    assert(reader.read(destination) == 3);
    assert(cast(string) destination[0 .. 3] == "abc");
    assert(destination[3 .. $] == [0x55, 0x55]);
    assert(reader.position == 3);
    assert(reader.read(destination) == 0);
    assert(reader.read(destination) == 0);
    assert(reader.position == 3);

    auto beyondEOF = SequentialAccessReader(atomicLoad(source), 10);
    assert(beyondEOF.read(destination) == 0);
    assert(beyondEOF.position == 10);
}

@("SequentialAccessReader handles short reads without skipping bytes") unittest
{
    auto source = new shared TestRandomAccessReader("abcde", 2);
    scope (exit)
        source.close();

    auto reader = SequentialAccessReader(atomicLoad(source));
    ubyte[4] destination;

    assert(reader.read(destination) == 2);
    assert(cast(string) destination[0 .. 2] == "ab");
    assert(reader.position == 2);
    assert(reader.read(destination) == 2);
    assert(cast(string) destination[0 .. 2] == "cd");
    assert(reader.position == 4);
    assert(reader.read(destination) == 1);
    assert(destination[0] == 'e');
    assert(reader.position == 5);
    assert(reader.read(destination) == 0);
}

@("SequentialAccessReader adapters keep independent cursors and borrow their source") unittest
{
    auto source = new shared TestRandomAccessReader("abcdefghij");
    scope (exit)
        source.close();

    ubyte[2] destination;
    {
        auto first = SequentialAccessReader(atomicLoad(source));
        auto second = SequentialAccessReader(atomicLoad(source), 5);

        assert(first.read(destination) == 2);
        assert(cast(string) destination[] == "ab");
        assert(second.position == 5);
        assert(second.read(destination) == 2);
        assert(cast(string) destination[] == "fg");
        assert(first.position == 2);
        assert(second.position == 7);
    }

    assert(source.readAt(8, destination) == 2);
    assert(cast(string) destination[] == "ij");
}

@("SequentialAccessReader rejects null and uninitialized sources") unittest
{
    import std.exception : assertThrown;

    assertThrown!Exception(SequentialAccessReader(null));
    SequentialAccessReader reader;
    ubyte[1] destination;
    assertThrown!Exception(reader.read(destination));
}

@("SequentialAccessReader preserves its cursor on failures and rejects overflow") unittest
{
    import std.exception : assertThrown;

    auto source = new shared TestRandomAccessReader("abcdefghij", size_t.max, true);
    scope (exit)
        source.close();

    auto reader = SequentialAccessReader(atomicLoad(source), 3);
    ubyte[2] destination;
    assertThrown!Exception(reader.read(destination));
    assert(reader.position == 3);

    auto overflow = SequentialAccessReader(atomicLoad(source), ulong.max);
    assertThrown!Exception(overflow.read(destination));
    assert(overflow.position == ulong.max);
}
