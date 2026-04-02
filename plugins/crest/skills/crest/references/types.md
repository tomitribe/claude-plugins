# Custom Type Editors

Register a `PropertyEditor` with `@Editor` to support custom parameter types.
Include the editor class in your `Loader` or pass it to `Main.builder().command()`
so crest discovers and registers it.

Two base class options:

**`AbstractConverter`** -- minimal, just implement string-to-object:

```java
@Editor(LocalDate.class)
public class LocalDateEditor extends AbstractConverter {
    @Override
    protected Object toObjectImpl(final String s) {
        return LocalDate.parse(s);
    }
}
```

**`PropertyEditorSupport`** -- full control, supports both string-to-object (`setAsText`)
and object-to-string (`getAsText`):

```java
@Editor(Environment.class)
public class EnvironmentEditor extends PropertyEditorSupport {
    @Override
    public void setAsText(final String text) throws IllegalArgumentException {
        final Environment env = Arrays.stream(Environment.values())
                .filter(e -> e.getName().equalsIgnoreCase(text))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Invalid environment: " + text));
        setValue(env);
    }

    @Override
    public String getAsText() {
        final Environment env = (Environment) getValue();
        return env != null ? env.getName() : "";
    }
}
```

# Type Conversion

Crest automatically converts CLI string arguments to Java types. The conversion
is handled by `org.tomitribe.util.editor.Converter` using these strategies in order:

1. **PropertyEditor** -- if a `PropertyEditor` is registered (via `@Editor` or Java's `PropertyEditorManager`)
2. **Enum** -- `Enum.valueOf()` with case fallbacks (exact, uppercase, lowercase)
3. **Constructor(String)** -- any public constructor taking a single `String` parameter
4. **Constructor(CharSequence)** -- any public constructor taking `CharSequence`
5. **Static factory method** -- any public static method taking `String` and returning the target type (e.g., `valueOf`, `of`, `parse`)

## Built-in Types

Primitives and wrappers (`int`, `Integer`, `boolean`, `Boolean`, etc.), `String`,
`File`, `URI`, `URL`, `Pattern`, `Path`, `Date`, `Character`, all enums,
`List<T>`, `Set<T>`, `Map<K,V>`, and arrays.

## Domain Wrapper Types (Recommended)

For positional arguments (non-options), prefer domain-specific wrapper types over
raw `String`. A class with a `public Constructor(String)` is automatically usable
as a CLI parameter type. This gives you type safety, validation, and self-documenting
method signatures.

```java
public class Product {
    private final String value;

    public Product(final String value) {
        final String lc = value.toLowerCase();
        if (!lc.equals(value)) {
            throw new ProductNotLowercaseException(value);
        }
        if (lc.startsWith("apache")) {
            throw new ProductPrefixException(value);
        }
        this.value = value;
    }

    public String get() { return value; }

    @Override
    public String toString() { return value; }

    @Exit(2)
    public static class ProductNotLowercaseException extends RuntimeException {
        public ProductNotLowercaseException(final String product) {
            super("Product name must be lowercase: " + product);
        }
    }

    @Exit(3)
    public static class ProductPrefixException extends RuntimeException {
        public ProductPrefixException(final String product) {
            super("Product name should not start with 'apache': " + product);
        }
    }
}

public class CustomerId {
    private final String id;

    public CustomerId(final String id) {
        if (id.length() != 18 || !id.startsWith("001")) {
            throw new InvalidCustomerIdFormatException(id);
        }
        this.id = id;
    }

    public String get() { return id; }

    @Exit(1)
    public static class InvalidCustomerIdFormatException extends RuntimeException {
        public InvalidCustomerIdFormatException(final String id) {
            super(String.format("Invalid customer ID format '%s'", id));
        }
    }
}
```

Use them as positional arguments -- Crest calls the `String` constructor automatically:

```java
@Command("list-release")
public Stream<S3File> listRelease(final Product product,
                                  final Version version,
                                  final Config config) { ... }

@Command
public PrintOutput extend(final CustomerId customerId,
                           final ExpirationDate expiration,
                           final Config config) { ... }
```

CLI usage: `list-release tomcat 9.0.1` / `extend 001ABC123456789012 2025-12-31`

A key benefit is that the class name appears in help output as the argument name.
Using `final Product product` produces `Usage: list-release Product Version` in help,
which is far more informative than `String String`. Wrapper constructors are also a
natural place for validation -- either direct checks that throw `@Exit`-annotated
exceptions, or Bean Validation annotations on constructor parameters.

Key conventions for wrapper types:
- Store the raw value in a `final` field
- Validate in the constructor, throwing `@Exit`-annotated exceptions
- Alternatively, use Bean Validation annotations on the constructor parameter
- Provide a `get()` method and `toString()`
- Implement `Comparable` when ordering matters
- Nest the exception classes inside the wrapper for cohesion

# Validation

Crest integrates Bean Validation (JSR-380). Built-in file validators:

```java
@Command
public void process(@Option("input") @Exists @Readable final File input,
                    @Option("output") @Directory final File outDir) { ... }
```

Built-in: `@Exists`, `@Readable`, `@Writable`, `@Executable`, `@Directory`

Custom validators:

```java
@Exists
@Constraint(validatedBy = {IsFile.Constraint.class})
@Target({PARAMETER})
@Retention(RUNTIME)
public @interface IsFile {
    String message() default "{org.example.IsFile.message}";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};

    class Constraint implements ConstraintValidator<IsFile, File> {
        @Override
        public boolean isValid(final File file,
                               final ConstraintValidatorContext ctx) {
            return file.isFile();
        }
    }
}
```
