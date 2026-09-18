module storage.types.validation.validator;

import std.format : format;
import std.traits : FieldNameTuple, hasUDA;

version (Have_unit_threaded)
{
    import unit_threaded;
}

/** Marks a struct as being a validator **/
struct Validator
{
}

/** Thrown when a value does not satisfy its declared validation attributes. */
class ValidationException : Exception
{
    string field;

    this(string field, string message, string file = __FILE__, size_t line = __LINE__)
    {
        this.field = field;
        super(message, file, line);
    }
}

/**
 * Validates every field on `value` that has a supported validation attribute.
 */
void validate(T)(auto ref const T value)
{
    // Iteration is over fields only.
    static foreach (fieldName; FieldNameTuple!T)
    {
        {
            // Retrieve the field declaration from the compile-time name
            alias field = __traits(getMember, T, fieldName);

            // Retrieve the UDAs attached to the field
            static foreach (attribute; __traits(getAttributes, field))
            {
                {
                    alias AttributeType = typeof(attribute);

                    static if (hasUDA!(AttributeType, Validator))
                    {
                        // Assert the presence of the `validateField` method
                        static assert(__traits(hasMember, AttributeType, "validateField"),
                            format!"Validator '%s' is missing the 'validateField' method."(
                                AttributeType));

                        // Invoke the concrete validator in the runtime value
                        attribute.validateField(
                            fieldName, __traits(getMember, value, fieldName));
                    }
                }
            }
        }
    }
}

@("Validator invokes supported field attributes") unittest
{
    @Validator
    struct MustBePositive
    {
        void validateField(S)(string fieldName, const S value) const
        {
            if (value <= 0)
            {
                throw new ValidationException(fieldName, "Value must be positive.");
            }
        }
    }

    struct UnrelatedAttribute
    {
    }

    struct Example
    {
        @MustBePositive() int count;
        @UnrelatedAttribute() string ignored;
    }

    validate(Example(1, "not inspected"));

    try
    {
        validate(Example(0, null));
        assert(0, "Expected validation to fail");
    }
    catch (ValidationException error)
    {
        assert(error.field == "count");
        assert(error.msg == "Value must be positive.");
    }
}
