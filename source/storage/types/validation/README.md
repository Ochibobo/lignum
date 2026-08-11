#### Validations

- Defines a set of validation attributes that can be applied to struct fields to validate their values at runtime.
- These validations are composable and can be used in combination to enforce complex constraints on the data.

- All validations must be marked with the @Validator() attribute.
- All validations must implement the `validateField` method.
- The `validateField` method accepts the field name and the field value as arguments.
- The `validateField` method throws a `ValidationException` when the field value violates a declared constraint.

**Current Validations**

- `@NotEmpty` - Marks a string field as being non-empty.
- `@MinLength(size_t limit)` - Marks a string field with its minimum permitted number of Unicode code points.
- `@MaxLength(size_t limit)` - Marks a string field with its maximum permitted number of Unicode code points.

**Adding New Validations**

- Define a new struct in its own file.
- Mark it with the @Validator() attribute.
- Implement the `validateField(S)(string fieldName, const S value) const` method.
- The `validateField` method accepts the field name and the field value as arguments.
- The `validateField` method throws a `ValidationException` when the field value violates a declared constraint.
- Add the new validation to the `public import` statement in `package.d` to make it available app-wide.