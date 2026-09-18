module storage.types.validation.max_length;

import std.format : format;
import std.traits : isSomeString;
import std.utf : count;
import storage.types.validation.validator : ValidationException, Validator, validate;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/**
 * Marks a string field with its maximum permitted number of Unicode code points.
 *
 * Params:
 *  limit = the maximum number of Unicode code points allowed in the field
 *
 * Throws:
 *  `ValidationException` when a field violates a declared constraint.
 */
@Validator()
struct MaxLength
{
    size_t limit;

    void validateField(S)(string fieldName, const S value) const
    {
        static assert(isSomeString!S, "@MaxLength can only be applied to string fields.");

        if (value.count > this.limit)
        {
            throw new ValidationException(
                fieldName,
                format!"Field '%s' cannot exceed %s characters."(fieldName, this.limit));
        }
    }
}

@("MaxLength validates Unicode code point limits") unittest
{
    struct Example
    {
        @MaxLength(4) string name;
    }

    // The boundary is inclusive and counts Unicode code points, not UTF-8 bytes.
    validate(Example("wood"));
    validate(Example("木木木木"));

    try
    {
        validate(Example("timber"));
        assert(0, "Expected validation to fail");
    }
    catch (ValidationException error)
    {
        assert(error.field == "name");
        assert(error.msg == "Field 'name' cannot exceed 4 characters.");
    }

    static assert(!__traits(compiles,
            MaxLength(4).validateField("number", 123)));
}
