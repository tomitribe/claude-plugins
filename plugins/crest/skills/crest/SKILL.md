# Crest - Annotation-Based CLI Framework

Java framework for building command-line interfaces using a JAX-RS-inspired annotation approach. Mark methods with `@Command`, parameters with `@Option`, and Crest handles argument parsing, type conversion, validation, help generation, and table formatting.

**Package:** `org.tomitribe.crest.api` (annotations), `org.tomitribe.crest` (runtime)

## Maven Coordinates

```xml
<!-- Runtime -->
<dependency>
    <groupId>org.tomitribe</groupId>
    <artifactId>tomitribe-crest</artifactId>
</dependency>
<!-- API (annotations and interfaces) -->
<dependency>
    <groupId>org.tomitribe</groupId>
    <artifactId>tomitribe-crest-api</artifactId>
</dependency>
```

Scaffold a new project:

```bash
mvn archetype:generate \
    -DarchetypeGroupId=org.tomitribe \
    -DarchetypeArtifactId=tomitribe-crest-archetype
```

## Quick Start

```java
@Command
public String hello(@Option("name") @Default("World") final String name,
                    @Option("greeting") @Default("Hello") final String greeting) {
    return greeting + ", " + name + "!";
}
```

CLI usage: `myapp hello --name=Alice --greeting=Hi`

## @Command

Marks a method as a CLI command. The method name becomes the command name.

```java
@Command
public String greet(@Option("name") @Default("World") final String name) {
    return "Hello, " + name;
}
```

### Custom Name

Override the method name, useful for Java reserved words:

```java
@Command("import")
public void _import(@Option("file") final File file) { ... }
```

### Description

One-line description shown in help listings:

```java
@Command(description = "Deploy the application to the target environment")
public void deploy(@Option("target") final String target) { ... }
```

### Custom Usage

Override the auto-generated synopsis:

```java
@Command(value = "commit", usage = "commit [options] <message> <file>")
public void commit(@Option("all") final boolean all,
                   final String message,
                   final File file) { ... }
```

### Interceptors

Attach interceptors directly:

```java
@Command(interceptedBy = {AuditInterceptor.class, TimingInterceptor.class})
public String deploy(@Option("target") final String target) { ... }
```

## @Option

Marks a parameter as a named CLI option. Parameters without `@Option` are positional arguments.

```java
@Command
public void upload(@Option("customer-id") final String customerId,
                   @Option("dry-run") @Default("false") final boolean dryRun,
                   final URI source) { ... }
```

CLI: `upload --customer-id=acme --dry-run /data`

Crest requires `=` between option and value (`--customer-id=acme`, not `--customer-id acme`). Boolean options are the exception -- `--dry-run` and `--dry-run=true` both work. An implicit negation `--no-dry-run` is generated for every boolean option.

### Aliases

Multiple names for the same option:

```java
@Option({"f", "force"}) final boolean force
```

CLI: `--force` or `-f`

### Inline Description

```java
@Option(value = "all", description = "commit all changed files") final boolean all
```

## @Default

Default value when the user doesn't supply the option. Converted to the parameter type.

```java
@Command
public void connect(@Option("host") @Default("localhost") final String host,
                    @Option("port") @Default("5432") final int port,
                    @Option("ssl") @Default("true") final boolean ssl) { ... }
```

### Variable Substitution

Supports `${...}` for system properties and environment variables:

```java
@Option("owner") @Default("${user.name}") final String owner
@Option("region") @Default("${AWS_REGION}") final String region
```

## @Required

Enforces that an option must be provided. Mutually exclusive with `@Default`.

```java
@Command
public void register(@Option("email") @Required final String email,
                     @Option("name") @Required final String name,
                     @Option("newsletter") @Default("false") final boolean newsletter) { ... }
```

## Command Groups

Place `@Command` on a class to define a group. Methods inside become sub-commands.

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

CLI: `config set --key=db.host --value=localhost`

Multiple classes can contribute to the same group by using the same `@Command` value.

## @Options — Reusable Option Bundles

Bundle related options into a reusable class. Inject into commands as a plain parameter (no annotation needed).

```java
@Options
public class Config {
    private final String name;
    private final String env;

    public Config(@Option("config") @Default("default") final String name,
                  @Option("env") @Default("prod") final String env) {
        this.name = name;
        this.env = env;
    }

    public String getName() { return name; }
    public String getEnv() { return env; }
}

@Command
public void deploy(final Config config,
                   @Option("version") final String version) { ... }
```

CLI: `deploy --config=staging --env=dev --version=2.1.0`

### Nillable

Use `nillable = true` to allow the object to be null when no values are provided:

```java
@Options(nillable = true)
public class Pagination {
    public Pagination(@Option("page") final int page,
                      @Option("size") @Default("20") final int size) { ... }
}
```

## @GlobalOptions

Like `@Options`, but automatically available to every command without declaring the parameter:

```java
@GlobalOptions
public class Verbosity {
    public Verbosity(@Option("verbose") @Default("false") final boolean verbose,
                     @Option("quiet") @Default("false") final boolean quiet) { ... }
}
```

## Return Types

| Type | Behavior |
|------|----------|
| `String` | Printed with newline |
| `void` | No output |
| `StreamingOutput` | Writes to `OutputStream` (functional interface) |
| `PrintOutput` | Writes to `PrintStream` (functional interface) |
| `Stream<T>`, `List<T>`, `Set<T>`, `Iterable<T>` | Each element on its own line via `toString()` |
| Collections with `@Table` | Formatted as table |

```java
@Command
public StreamingOutput export(final Config config) {
    return outputStream -> {
        final PrintWriter pw = new PrintWriter(outputStream);
        for (final Record record : loadRecords(config)) {
            pw.println(record.toCsv());
        }
        pw.flush();
    };
}
```

## I/O Stream Injection

Inject stdin, stdout, stderr directly. Hidden from help output.

```java
@Command
public void transform(@In final InputStream in,
                      @Out final PrintStream out,
                      @Err final PrintStream err,
                      @Option("format") @Default("json") final String format) {
    // Read from in, write to out, errors to err
}
```

## Type Conversion

Crest converts CLI string arguments to Java types using this chain (first match wins):

1. **PropertyEditor** -- registered via `@Editor`
2. **Enum** -- `Enum.valueOf()` with case fallbacks (exact, uppercase, lowercase)
3. **Constructor(String)** -- public constructor taking a single `String`
4. **Constructor(CharSequence)** -- public constructor taking a single `CharSequence`
5. **Static factory** -- public static method taking `String` returning the type (`valueOf`, `of`, `parse`)

Built-in types: primitives, wrappers, `String`, `File`, `Path`, `URI`, `URL`, `Pattern`, `Date`, `Character`, all enums, `List<T>`, `Set<T>`, `Map<K,V>`, arrays.

### Domain Wrapper Types

Any class with a `public Constructor(String)` is automatically usable as a CLI parameter. The class name appears in help output, making signatures self-documenting.

```java
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
            super("Invalid customer ID format: " + id);
        }
    }
}

@Command
public PrintOutput extend(final CustomerId customerId,
                           final ExpirationDate expiration) { ... }
```

CLI: `extend 001ABC123456789012 2025-12-31`

Conventions for wrapper types:
- Store the raw value in a `final` field
- Validate in the constructor, throwing `@Exit`-annotated exceptions
- Provide a `get()` method and `toString()`
- Nest exception classes inside the wrapper

## @Exit — Exit Codes

Maps exception types to process exit codes:

```java
@Exit(1)
public static class InvalidInputException extends RuntimeException {
    public InvalidInputException(final String msg) { super(msg); }
}

@Exit(value = 400, help = true)  // also prints command help after error
public class MissingArgumentException extends IllegalArgumentException { ... }
```

When thrown, Crest prints the message to stderr and exits with the specified code.

## Validation

### Built-in File Validators

```java
@Command
public void process(@Option("input") @Exists @Readable final File input,
                    @Option("output") @Directory @Writable final File outDir) { ... }
```

| Annotation    | Validates                 |
|---------------|---------------------------|
| `@Exists`     | File or directory exists   |
| `@Readable`   | File is readable           |
| `@Writable`   | File is writable           |
| `@Executable` | File is executable         |
| `@Directory`  | Path is a directory        |

### Bean Validation (JSR-380)

Standard `@Min`, `@Max`, `@NotNull`, etc. annotations work on command parameters.

### Custom Validators

Compose built-in validators and add custom checks:

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

## @Table — Tabular Output

Formats collection return types as tables. Works with `Stream`, `List`, `Set`, and arrays.

```java
@Command
@Table(fields = "id name version status", sort = "name", border = Border.unicodeSingle)
public Stream<Package> list() {
    return packageService.findAll();
}
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `fields` | Space-delimited getter/field names for columns. Supports dot notation for nested properties (`expiration.date`) |
| `sort` | Space-delimited field names to sort by |
| `header` | Include header row (default `true`) |
| `border` | Border style from `Border` enum (default `asciiCompact`) |

### Border Styles

| Enum Value | Description |
|---|---|
| `asciiCompact` | Compact ASCII borders (default) |
| `asciiDots` | Dotted ASCII borders |
| `asciiSeparated` | ASCII with row separators |
| `githubMarkdown` | GitHub-flavored Markdown table |
| `mysqlStyle` | MySQL client output style |
| `unicodeSingle` | Single-line Unicode box drawing |
| `unicodeDouble` | Double-line Unicode box drawing |
| `unicodeSingleSeparated` | Single-line Unicode with row separators |
| `whitespaceCompact` | Compact whitespace-only alignment |
| `whitespaceSeparated` | Whitespace with blank line separators |
| `tsv` | Tab-separated values |
| `csv` | Comma-separated values |
| `reStructuredTextGrid` | reStructuredText grid table |
| `reStructuredTextSimple` | reStructuredText simple table |
| `redditMarkdown` | Reddit-flavored Markdown table |

### TableOptions — User-Overridable at Runtime

Add `TableOptions` as a parameter to enable CLI flags for overriding table settings:

```java
@Command
@Table(fields = "name state schedule command", sort = "name")
public Stream<Job> list(final Config config, final TableOptions tableOptions) {
    return jobService.stream(config);
}
```

Available CLI flags: `--table-border=unicodeSingle`, `--no-table-header`, `--table-sort=state`, `--table-fields="name state"`, `--tsv`

## @Editor — Custom Type Conversion

Registers a `PropertyEditor` for CLI parsing and table display.

### Simple Conversion

```java
@Editor(LocalDate.class)
public class LocalDateEditor extends AbstractConverter {
    @Override
    protected Object toObjectImpl(final String s) {
        return LocalDate.parse(s);
    }
}
```

### Full Control (Parse + Display)

```java
@Editor(Instant.class)
public class InstantEditor extends PropertyEditorSupport {
    private static final DateTimeFormatter FMT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").withZone(ZoneOffset.UTC);

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

`setAsText` is used for CLI argument parsing; `getAsText` is used for `@Table` cell rendering.

## Interceptors

Cross-cutting concerns (logging, timing, auditing) using an around-invoke pattern.

### Defining an Interceptor

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

### CrestContext

- `proceed()` -- continue chain and invoke command (must be called)
- `getMethod()` -- the command's `java.lang.reflect.Method`
- `getParameters()` -- mutable list of resolved parameters
- `getName()` -- command name
- `getParameterMetadata()` -- parameter type/name metadata

### Attaching via interceptedBy

```java
@Command(interceptedBy = TimingInterceptor.class)
public String deploy(@Option("target") final String target) { ... }
```

### Custom Interceptor Annotations

**Pattern A — Explicit class reference:**

```java
@CrestInterceptor(AuditInterceptor.class)
@Retention(RUNTIME)
@Target({METHOD, TYPE})
public @interface Audited {}

@Audited
@Command
public String transfer(@Option("from") final String from,
                        @Option("to") final String to) { ... }
```

**Pattern B — Indirect resolution (used by @Table):**

```java
@CrestInterceptor
@Retention(RUNTIME)
@Target({METHOD, TYPE})
public @interface Timed {}

@Timed  // links interceptor to annotation
public class TimedInterceptor {
    @CrestInterceptor
    public Object intercept(final CrestContext ctx) { ... }
}
```

With Pattern B, the interceptor class must be registered via a `Loader` or `Main.builder().load()`.

## Help

Built-in `help` command is registered automatically:

```
myapp help                  # list all commands
myapp help deploy           # full man page for "deploy"
myapp help config set       # man page for sub-command
```

### Description Sources (priority order)

**Command descriptions:**
1. `@Command(description = "...")`
2. First sentence of javadoc (extracted at compile time)

**Option descriptions:**
1. `OptionDescriptions.properties` ResourceBundle (same package as command class)
2. `@Option(description = "...")`
3. Javadoc `@param` tags

Man pages include sections: NAME, SYNOPSIS, DESCRIPTION, OPTIONS, DEPRECATED, SEE ALSO, AUTHORS — populated from javadoc tags.

## Entry Point

### ServiceLoader Discovery

```java
public static void main(final String[] args) throws Exception {
    new Main().run(args);
}
```

Register a `Loader` in `META-INF/services/org.tomitribe.crest.api.Loader`:

```java
public class MyLoader implements Loader {
    @Override
    public Iterator<Class<?>> iterator() {
        return Loader.of(
            ConfigCommands.class,
            S3Commands.class,
            AuditInterceptor.class,
            InstantEditor.class
        ).iterator();
    }
}
```

### Programmatic Setup

```java
final Main main = Main.builder()
        .command(HelloCommand.class)
        .command(ConfigCommands.class)
        .load(AuditInterceptor.class)
        .load(InstantEditor.class)
        .name("myapp")
        .version("1.0.0")
        .build();

main.run(args);
```

Builder options: `command(Class)`, `load(Class)`, `name(String)`, `version(String)`, `out(PrintStream)`, `err(PrintStream)`, `in(InputStream)`, `exit(Consumer<Integer>)`, `noexit()`.

`run(args)` handles exceptions internally. `exec(args)` returns the result and lets exceptions propagate.

## Testing

```java
@Test
public void testDefaultGreeting() throws Exception {
    final PrintString out = new PrintString();
    final Main main = Main.builder()
            .command(HelloCommand.class)
            .out(out)
            .build();

    main.run("hello");

    assertEquals(String.format("Hello, World!%n"), out.toString());
}
```

Key patterns:
- Use `Main.builder()` for isolated test instances
- Use `PrintString` (from `tomitribe-util`) to capture stdout/stderr
- Use `String.format("%n")` for platform-independent newlines
- Assert full output with `assertEquals`, not partial matches
- Use `run()` for side-effect commands, `exec()` for return values

## Naming Conventions

- Method name becomes command name (unless `@Command("name")` overrides)
- Underscores in method/parameter names become hyphens in CLI: `dry_run` becomes `--dry-run`
- Class-level `@Command` defines group name; method-level defines sub-command
