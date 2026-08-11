module storage.types.validation.not_empty;

import std.format : format;
import std.traits : isSomeString;
import storage.types.validation.validator;

/**
 * Marks a string field as being non-empty.
 *
 * Throws:
 *  `ValidationException` when a field violates a declared constraint.
 */
@Validator()
struct NotEmpty
{
    void validateField(S)(string fieldName, const S value) const
    {
        static assert(isSomeString!S, "@NotEmpty can only be applied to string fields.");

        if (value.length == 0)
        {
            throw new ValidationException(
                fieldName,
                format!"Field '%s' cannot be empty."(fieldName));
        }
    }
}

unittest
{
    struct Example
    {
        @NotEmpty() string name;
    }

    validate(Example("wood"));
    validate(Example("木木木木"));

    try
    {
        validate(Example(""));
        assert(0, "Expected validation to fail");
    }
    catch (ValidationException error)
    {
        assert(error.field == "name");
        assert(error.msg == "Field 'name' cannot be empty.");
    }

    static assert(!__traits(compiles, NotEmpty.validateField(123)));
}
