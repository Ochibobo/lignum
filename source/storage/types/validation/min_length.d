module storage.types.validation.min_length;

import std.format : format;
import std.traits : isSomeString;
import std.utf : count;

import storage.types.validation.validator;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * Marks a string field with its minimum permitted number of Unicode code points.
 *
 * Params:
 *  limit = the minimum number of Unicode code points allowed in the field
 *
 * Throws:
 *  `ValidationException` when a field violates a declared constraint.
 */
@Validator()
struct MinLength
{
    size_t limit;

    void validateField(S)(string fieldName, const S value) const
    {
        static assert(isSomeString!S, "@MinLength can only be applied to string fields.");

        if (value.count < this.limit)
        {
            throw new ValidationException(
                fieldName,
                format!"Field '%s' must be at least %s characters."(fieldName, this.limit));
        }
    }
}

@("MinLength validates Unicode code point limits") unittest
{
    struct Example
    {
        @MinLength(4) string name;
    }

    // The boundary is inclusive and counts Unicode code points, not UTF-8 bytes.
    validate(Example("wood"));
    validate(Example("木木木木"));

    try
    {
        validate(Example("tim"));
        assert(0, "Expected validation to fail");
    }
    catch (ValidationException error)
    {
        assert(error.field == "name");
        assert(error.msg == "Field 'name' must be at least 4 characters.");
    }

    static assert(!__traits(compiles,
            MinLength(4).validateField("number", 123)));
}
