# Crest - Java CLI Framework

Annotation-driven framework for building command-line tools in Java, styled after JAX-RS.
Methods become commands, parameters become options. Help text, validation, and type conversion are automatic.

**Package:** `org.tomitribe.crest`

## Maven Coordinates

```xml
<dependency>
    <groupId>org.tomitribe</groupId>
    <artifactId>tomitribe-crest</artifactId>
</dependency>
<dependency>
    <groupId>org.tomitribe</groupId>
    <artifactId>tomitribe-crest-api</artifactId>
</dependency>
```

## Core Annotations

### @Command (Method or Type)

Marks a method as a CLI command. When placed on a class, it defines a command group (sub-commands).

```java
@Command(value = "config", description = "Manage configuration")
public class ConfigCommands {

    @Command(description = "Add a new config value")
    public void add(final Name name,
                    @Required @Option("value") final String value) { ... }

    @Command(description = "Remove a config value")
    public void remove(final Name name) { ... }

    @Command("import")
    public void _import(final Config config,
                        @Option("file") final File file) { ... }
}
```

Parameters:
- `value` -- command name (defaults to method name)
- `description` -- one-line description shown in command listings
- `usage` -- custom usage/synopsis text
- `interceptedBy` -- array of interceptor classes

### @Option (Parameter)

Marks a parameter as a named CLI option. Unannotated parameters are positional arguments.

```java
@Command
public void upload(@Option("customer-id") final String customerId,
                   @Option({"f", "force"}) final boolean force,
                   @Option("skip") @Default(".DS_Store|cust.*") final Pattern skip,
                   final URI source) { ... }
```

Parameters:
- `value` -- one or more option names (aliases)
- `description` -- help text

CLI usage: `upload --customer-id acme --force /data`

### @Default (Parameter)

Provides a default value. Supports system property and environment variable substitution.

```java
@Option("host") @Default("localhost") final String host,
@Option("port") @Default("5432") final int port,
@Option("owner") @Default("${user.name}") final String owner,
@Option("dry-run") @Default("true") final Boolean dryRun
```

### @Required (Parameter)

Enforces that an option must be provided. Framework throws a validation error if missing.

```java
@Option("email") @Required final String email
```

## Options Classes

Bundle related options into a reusable class with `@Options`. The constructor parameters define the options.

```java
@Options
public class Config {
    public Config(@Option("config") @Default("default") final String name,
                  @Option("env") @Default("prod") final String env) { ... }
}

@Options
public class CustomerIds {
    public CustomerIds(@Option("customer-id") final List<String> customerIds,
                       @Option("customers") final File customerIdFile) { ... }
}
```

Inject into commands as a plain parameter (no annotation needed):

```java
@Command
public void deploy(final Config config,
                   final CustomerIds customers,
                   @Option("version") final String version) { ... }
```

Use `@Options(nillable = true)` to allow null when no values are provided.

### @GlobalOptions

Same as `@Options` but available to every command automatically.

## I/O Streams

Inject stdin, stdout, stderr with `@In`, `@Out`, `@Err`. These are hidden from help text.

```java
@Command
public void deploy(@Out final PrintStream out,
                   @Err final PrintStream err,
                   @Option("target") final String target) {
    out.println("Deploying to " + target);
}
```

## Return Types

Commands can return several types. The framework handles output automatically.

```java
// String -- printed to stdout
@Command
public String hello(@Option("name") @Default("World") final String name) {
    return "Hello, " + name;
}

// StreamingOutput -- write to OutputStream
@Command
public StreamingOutput export(final Config config) {
    return outputStream -> {
        final PrintWriter pw = new PrintWriter(outputStream);
        // ... write output
    };
}

// PrintOutput -- write to PrintStream
@Command
public PrintOutput upload(final CustomerIds customerIds,
                          @Option("dry-run") @Default("true") final Boolean dryRun) {
    return out -> {
        out.println("Uploading for " + customerIds);
    };
}

// Stream/List/Array -- iterable output (or table-formatted with @Table)
@Command
@Table(fields = "name state schedule command", sort = "name")
public Stream<Job> list(final Config config) { ... }
```

## Table Formatting

Annotate commands that return collections with `@Table` for automatic tabular output.

```java
@Command
@Table(fields = "id name version", sort = "name", border = Border.unicodeSingle)
public List<Package> list() { ... }

@Command
@Table(fields = "accountId customer cores software expiration.date expiration.expired",
       sort = "customer")
public Stream<Subscription> info(final Config config) { ... }

@Command
@Table(fields = "key value", sort = "key")
public Set<Map.Entry<Object, Object>> list(final Config config, final String path) { ... }
```

Parameters:
- `fields` -- space-delimited getter/field names (supports nested: `expiration.date`)
- `sort` -- space-delimited field names for sorting
- `header` -- include header row (default: true)
- `border` -- border style enum

### Border Styles

`Border.asciiCompact` (default), `asciiDots`, `asciiSeparated`, `githubMarkdown`,
`mysqlStyle`, `unicodeDouble`, `unicodeSingle`, `unicodeSingleSeparated`,
`whitespaceCompact`, `whitespaceSeparated`, `tsv`, `csv`,
`reStructuredTextGrid`, `reStructuredTextSimple`, `redditMarkdown`

### TableOptions

Add `TableOptions` as a command parameter to let users override table settings at runtime:

```java
@Command
@Table(fields = "name state schedule", sort = "name")
public Stream<Job> list(final Config config, final TableOptions tableOptions) { ... }
```

CLI usage: `list --table-border=unicodeSingle --no-table-header --table-sort=state --tsv`

### Programmatic Table Building

Use `TableOutput.builder()` to build table output from objects programmatically
(uses reflection to extract fields, same as `@Table`). `TableOutput` implements
`PrintOutput`, so it can be returned directly from a command method:

```java
@Command
public TableOutput report(final Config config) {
    final List<Account> accounts = loadAccounts(config);

    return TableOutput.builder()
            .data(accounts)
            .fields("id name email status")
            .sort("name")
            .border(Border.asciiCompact)
            .header(true)
            .build();
}
```

`TableOutput.Builder` options:
- `data(Iterable<?>)`, `data(Stream<?>)`, `data(Object[])` -- the data source
- `fields(String)` -- space-delimited field/getter names
- `sort(String)` -- space-delimited sort fields
- `border(Border)` -- border style enum value
- `header(Boolean)` -- include header row

To let users override table settings at runtime, accept `TableOptions` and pass
it to the builder via `options()`. Builder methods are applied in call order --
values set after `options()` override it, and `options()` overrides values set
before it. Null values in `TableOptions` do not override existing settings.

```java
@Command
public TableOutput report(final Config config, final TableOptions tableOptions) {
    final List<Account> accounts = loadAccounts(config);

    return TableOutput.builder()
            .data(accounts)
            .fields("id name email status")
            .sort("name")
            .border(Border.asciiCompact)
            .header(true)
            .options(tableOptions)
            .build();
}
```

CLI usage: `report --table-border=unicodeSingle --table-sort=email --no-table-header`

The builder also accepts the internal `Options` object via an overloaded `options()` method.

### Table Cell Formatting

Table cells are rendered by first checking for a registered `PropertyEditor` for
the field's type. If an editor is found, `getAsText()` is used. Otherwise, the
cell falls back to `toString()`.

This means any `@Editor` registered via the `Loader` or `Main.builder()` that
implements `getAsText()` will automatically control how that type appears in tables.
For example, to display `java.time.Instant` in a readable format:

```java
@Editor(Instant.class)
public class InstantEditor extends PropertyEditorSupport {
    private static final DateTimeFormatter FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
                    .withZone(ZoneOffset.UTC);

    @Override
    public void setAsText(final String text) {
        setValue(Instant.parse(text));
    }

    @Override
    public String getAsText() {
        final Instant instant = (Instant) getValue();
        return instant != null ? FMT.format(instant) : "";
    }
}
```

Include it in your `Loader` or `Main.builder().load(InstantEditor.class)`.
The same editor handles both CLI argument parsing (`setAsText`) and table display
(`getAsText`), so `2025-03-08T14:30:00Z` renders as `2025-03-08 14:30` in tables.

## Loader Mechanism

The `Loader` is the central registry for all classes crest needs to discover.
It returns `@Command` classes, `@CrestInterceptor` classes, and `@Editor` classes.
Implement `org.tomitribe.crest.api.Loader`:

```java
public class MyLoader implements Loader {
    @Override
    public Iterator<Class<?>> iterator() {
        return Loader.of(
            // Command classes
            ConfigCommands.class,
            S3Commands.class,
            CustomerCommands.class,
            // Interceptor classes
            AuditInterceptor.class,
            // Editor classes
            InstantEditor.class
        ).iterator();
    }
}
```

Register in `META-INF/services/org.tomitribe.crest.api.Loader`:
```
com.example.cli.MyLoader
```

When using `Main.builder()`, use `command()` for `@Command` classes and `load()`
for non-command classes like editors and interceptors:

```java
Main.builder()
        .command(ConfigCommands.class)
        .command(S3Commands.class)
        .load(AuditInterceptor.class)
        .load(InstantEditor.class)
        .build();
```

Crest inspects each class: if annotated with `@Editor`, it registers the editor;
if annotated with `@CrestInterceptor`, it registers the interceptor; otherwise it
processes it as a `@Command` class.

## Exit Codes

Annotate exceptions with `@Exit` to control the process exit code:

```java
@Exit(1)
public static class InvalidCustomerIdFormatException extends RuntimeException {
    public InvalidCustomerIdFormatException(final String id) {
        super("Invalid customer ID format: " + id);
    }
}

@Exit(28)
public static class NoCustomerIdsSuppliedException extends RuntimeException {
    public NoCustomerIdsSuppliedException() {
        super("Supply at least one --customer-id or --customers file");
    }
}
```

Use `@Exit(value = 1, help = true)` to also print help after the error message.

## Custom Type Editors

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

## Type Conversion

Crest automatically converts CLI string arguments to Java types. The conversion
is handled by `org.tomitribe.util.editor.Converter` using these strategies in order:

1. **PropertyEditor** -- if a `PropertyEditor` is registered (via `@Editor` or Java's `PropertyEditorManager`)
2. **Enum** -- `Enum.valueOf()` with case fallbacks (exact, uppercase, lowercase)
3. **Constructor(String)** -- any public constructor taking a single `String` parameter
4. **Constructor(CharSequence)** -- any public constructor taking `CharSequence`
5. **Static factory method** -- any public static method taking `String` and returning the target type (e.g., `valueOf`, `of`, `parse`)

### Built-in Types

Primitives and wrappers (`int`, `Integer`, `boolean`, `Boolean`, etc.), `String`,
`File`, `URI`, `URL`, `Pattern`, `Path`, `Date`, `Character`, all enums,
`List<T>`, `Set<T>`, `Map<K,V>`, and arrays.

### Domain Wrapper Types (Recommended)

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

## Validation

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

## Help and Documentation

Crest provides a built-in `help` command and generates man-page-style documentation automatically.

### Built-in Help Command

Registered automatically. No setup required.

```bash
myapp help              # Lists all commands with descriptions
myapp help commit       # Full man page for "commit"
myapp help config set   # Man page for sub-command "set" in group "config"
```

### Command Descriptions in Listings

The `help` command shows a one-line description next to each command name.
The description is resolved from two sources in priority order:

**1. `@Command(description = "...")`** -- primary source, inline in the annotation:

```java
@Command(value = "config", description = "Manage configuration")
public class ConfigCommands {

    @Command(description = "Set a config value")
    public void set(@Option("key") final String key,
                    @Option("value") final String value) { ... }

    @Command(description = "Get a config value")
    public void get(@Option("key") final String key) { ... }
}
```

**2. First sentence of method javadoc** -- fallback, extracted at compile time by the
`HelpProcessor` annotation processor. The first sentence is determined by splitting
on period-space (`". "`):

```java
/**
 * Generates a signed JWT token for the given customer. The token
 * includes the customer ID and expiration date.
 */
@Command("generate")
public String generate(...) { ... }
```

The first sentence ("Generates a signed JWT token for the given customer") is used.
Note: javadoc fallback only works for methods (not for class-level group descriptions)
and requires the annotation processor to run during compilation.

Resulting help output:

```
Commands:

   config     Manage configuration
   generate   Generates a signed JWT token for the given customer
```

Sub-command listings work the same way:

```
Usage: config [subcommand] [options]

Sub commands:

   get   Get a config value
   set   Set a config value
```

### Command Listing Format

The listing is formatted as: 3 spaces + command name (left-aligned, padded to longest name + 3 spaces) + description.
The padding is computed dynamically from the longest command name in the group.

### Description Resolution for Groups and Overloads

**Command groups** (`CmdGroup`): When multiple classes contribute to the same group via
`@Command("sameName")`, the description comes from whichever class has a non-empty
`@Command(description)`. All contributing classes are checked, so it doesn't matter
which class is registered first.

**Overloaded commands** (`OverloadedCmdMethod`): When multiple methods share the same
command name but have different signatures, the description comes from whichever
overload has a non-null description. All overloads are searched.

### Man Page Generation

Running `help <command>` renders a structured man page with sections:
NAME, SYNOPSIS, DESCRIPTION, OPTIONS, DEPRECATED, SEE ALSO, AUTHORS.

The content is sourced from **method javadoc**, extracted at compile time by the
`HelpProcessor` annotation processor and stored in
`META-INF/crest/{className}/{commandName}.{index}.properties`.

```java
/**
 * Generates a signed JWT token for the given customer.
 *
 * The token includes the customer ID and expiration date,
 * encrypted with the configured private key.
 *
 * @param customerId the customer account identifier
 * @param expiration when the token should expire
 */
@Command("generate")
public String generate(@Option("customer-id") final String customerId,
                       @Option("expiration") final LocalDate expiration) { ... }
```

The javadoc body becomes the DESCRIPTION section. The `@param` tags become
option descriptions (as a fallback -- see priority below). Tags `@deprecated`,
`@see`, and `@author` populate their respective man page sections.

The description text supports markdown-like formatting: headings (`#` or `===`),
bullets (`-`), and preformatted blocks (4-space indent).

### @Command `usage` Parameter

Overrides the auto-generated SYNOPSIS line. If omitted, crest builds it from the
method signature as `commandName [options] arg1 arg2...`.

```java
@Command(value = "commit", usage = "commit [options] <message> <file>")
public void commit(...) { }
```

### Option Description Sources (Priority Order)

Three sources for the description shown next to each `--flag` in help output:

**1. `OptionDescriptions.properties`** -- highest priority. A ResourceBundle in the
same package as the command class:

```properties
# file: com/example/cli/OptionDescriptions.properties
recursive=recurse into directories
links=copy symlinks as symlinks

# Command-specific key takes precedence over the bare key
rsync.progress=don't show progress during transfer
progress=this is not the description that will be chosen
```

Lookup order: `commandName.optionName` then `optionName`.

**2. `@Option(description = "...")`** -- inline in the annotation:

```java
@Option(value = "all", description = "commit all changes") final boolean all
```

**3. Javadoc `@param` tags** -- lowest priority fallback, extracted at compile time:

```java
/**
 * @param everything indicates all changes should be committed
 */
@Command("commit")
public void commit(@Option("all") final boolean everything) { }
```

### @Exit with Help

When `help = true`, the error message is printed followed by the command's help text:

```java
@Exit(value = 400, help = true)
public class MissingArgumentException extends IllegalArgumentException { ... }
```

Used internally so users see correct usage on parse errors.

### Terminal Formatting

Man pages are formatted with:
- Text wrapping to terminal width
- ANSI color highlighting for `--flags` and `` `code` ``
- Justified text with margin padding
- Pager support (pipes through `less` if available)

## Interceptors

Define cross-cutting concerns with `@CrestInterceptor`. The interceptor method
can have any name but must take `CrestContext` and return `Object`:

```java
public class TimingInterceptor {
    @CrestInterceptor
    public Object time(final CrestContext ctx) {
        final long start = System.currentTimeMillis();
        try {
            return ctx.proceed();
        } finally {
            System.err.println(ctx.getName() + " took " +
                (System.currentTimeMillis() - start) + "ms");
        }
    }
}
```

`CrestContext` provides:
- `proceed()` -- continue the interceptor chain
- `getMethod()` -- the command's `java.lang.reflect.Method`
- `getParameters()` -- mutable list of parameters (can modify before proceeding)
- `getName()` -- the command name
- `getParameterMetadata()` -- parameter types, names, and nesting info

### Attaching Interceptors

**Direct attachment** via `@Command(interceptedBy = ...)`:

```java
@Command(interceptedBy = TimingInterceptor.class)
public String deploy(...) { ... }
```

### Custom Interceptor Annotations

Instead of listing interceptor classes in `@Command(interceptedBy)`, create a custom
annotation that represents the interceptor. There are two patterns:

**Pattern A: Explicit reference** -- the annotation names its interceptor class:

```java
@CrestInterceptor(AuditInterceptor.class)
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.TYPE})
public @interface Audited {
}

public class AuditInterceptor {
    @CrestInterceptor
    public Object intercept(final CrestContext ctx) {
        log(ctx.getName(), ctx.getParameters());
        return ctx.proceed();
    }
}

// Usage -- cleaner than interceptedBy:
@Audited
@Command
public String transfer(...) { ... }
```

**Pattern B: Indirect resolution** -- the interceptor class is annotated with the
custom annotation. The framework finds the interceptor by matching the annotation:

```java
@CrestInterceptor
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.TYPE})
public @interface Timed {
}

@Timed  // Links this interceptor to the @Timed annotation
public class TimedInterceptor {
    @CrestInterceptor
    public Object intercept(final CrestContext ctx) {
        final long start = System.nanoTime();
        try {
            return ctx.proceed();
        } finally {
            System.err.printf("%s: %dms%n", ctx.getName(),
                (System.nanoTime() - start) / 1_000_000);
        }
    }
}

// Usage:
@Timed
@Command
public String process(...) { ... }
```

With Pattern B, the interceptor class must be returned by a `Loader` so the
framework can discover it.

The built-in `@Table` annotation uses Pattern B -- it is a `@CrestInterceptor`
annotation, and `TableInterceptor` is annotated with `@Table`.

Custom annotations can also carry parameters (like `@Table` does with `fields`,
`sort`, etc.) which the interceptor can read from the method's annotations at runtime.

## Execution Entry Point

```java
public static void main(final String[] args) throws Exception {
    final Main main = new Main();
    main.run(args);
}
```

`Main` discovers commands via ServiceLoader. Use `main.exec(args)` to get the return value programmatically.

### Main.builder()

For programmatic setup without ServiceLoader discovery:

```java
final Main main = Main.builder()
        .command(ConfigCommands.class)
        .command(DeployCommands.class)
        .name("mytool")
        .version("1.2.3")
        .build();

main.run(args);
```

Builder options:
- `command(Class<?>)` -- add a `@Command` class. If no classes are added, discovery falls back to the classpath `Loader`
- `load(Class<?>)` -- add any class the `Loader` would return (`@Editor`, `@CrestInterceptor`, or `@Command`)
- `name(String)` -- root command name for help output (defaults to `System.getProperty("cmd")` or `System.getenv("CMD")`)
- `version(String)` -- version shown in help output
- `out(PrintStream)` -- redirect stdout (default: `System.out`)
- `err(PrintStream)` -- redirect stderr (default: `System.err`)
- `in(InputStream)` -- redirect stdin (default: `System.in`)
- `env(String, String)` -- add/override an environment variable
- `env(Map)` -- replace the entire environment map
- `property(String, String)` -- add/override a system property
- `properties(Properties)` -- replace the entire properties
- `exit(Consumer<Integer>)` -- custom exit handler (default: `System::exit`)
- `noexit()` -- disable exit calls (useful for testing)
- `provider(TargetProvider)` -- custom instance provider for command classes

## Testing

Use `Main.builder()` to test commands in-process without ServiceLoader or `System.exit`:

```java
@Test
public void testHelpListing() {
    final PrintString out = new PrintString();
    final Main main = Main.builder()
            .command(MyCommands.class)
            .out(out)
            .build();

    main.run("help");

    assertEquals(String.format("Commands: %n" +
            "%n" +
            "   deploy   Deploy the application%n" +
            "   help     %n" +
            "   status   Show current status%n"), out.toString());
}
```

Key patterns:
- Use `PrintString` (from tomitribe-util) to capture output
- Use `Main.builder().out(out)` to redirect help/command output
- Use `Main.builder().err(err)` to capture error output separately
- Use `main.run(...)` for void execution (handles exceptions internally)
- Use `main.exec(...)` when you need the return value
- Use `String.format("...%n...")` with `%n` for platform-independent newline assertions
- Always assert full output with `assertEquals`, not partial matches with `contains`

## Enum Parameters

Enums are automatically converted from CLI strings:

```java
public enum Language { EN, ES, FR }

@Command
public String hello(@Option("language") @Default("EN") final Language lang,
                    @Option("name") @Default("World") final String name) {
    return lang.greet(name);
}
```

CLI usage: `hello --language ES --name Juan`

## List and Array Parameters

Options can accept multiple values:

```java
@Command
public void tag(@Option("tag") final List<String> tags,
                @Option("exclude") final Pattern[] excludes) { ... }
```

CLI usage: `tag --tag=v1 --tag=v2 --exclude="test.*"`

Positional var-args:

```java
@Command
public void rsync(@Option("recursive") final boolean recursive,
                  final URI[] sources,
                  final URI dest) { ... }
```

CLI usage: `rsync --recursive src1 src2 dest/`
