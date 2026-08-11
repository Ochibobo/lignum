module storage.types.id;

/**
*   An id is a value that is used to uniquely identify a record in `duramen`.
*   This is the base interface for all ids.
*/
interface ID(T)
{
    @property T value() const;
}
