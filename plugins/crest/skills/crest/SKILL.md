---
name: crest
description: "Reference for org.tomitribe.crest Java CLI framework. TRIGGER when: code imports from org.tomitribe.crest, uses @Command annotations, or user is building annotation-driven command-line tools in Java. DO NOT TRIGGER when: working with picocli, JCommander, or other CLI frameworks."
---

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

### Multi-Level Command Groups

Command groups can nest to any depth using space-separated names in `@Command`.
Each token becomes a level in the hierarchy.

```java
/**
 * Quote management
 */
@Command("quote")
public class QuoteCommands {

    /** Create a quote */
    @Command
    public void create(@Option("name") final String name) { ... }

    /** Remove a quote */
    @Command
    public void remove(@Option("id") final String id) { ... }
}

/**
 * Manage line items
 */
@Command("quote line-item")
public class QuoteLineItemCommands {

    /** Create a line item */
    @Command
    public void create(@Option("product") final String product,
                       @Option("quantity") final int quantity) { ... }

    /** Delete a line item */
    @Command
    public void delete(@Option("id") final String id) { ... }

    /** List line items */
    @Command
    public void list() { ... }
}
```

CLI usage: `quote create --name="Acme"`, `quote line-item create --product=Widget --quantity=10`

The resulting hierarchy:

```
quote
├── create       Create a quote
├── remove       Remove a quote
└── line-item
    ├── create   Create a line item
    ├── delete   Delete a line item
    └── list     List line items
```

#### Method-Level Path Concatenation

Class and method `@Command` values concatenate following the JAX-RS `@Path` model.
A method can contribute additional group levels:

```java
@Command("quote")
public class QuoteCommands {

    /** Create a quote */
    @Command
    public void create(@Option("name") final String name) { ... }

    /** Create a line item */
    @Command("line-item create")
    public void lineItemCreate(@Option("product") final String product) { ... }

    /** Delete a line item */
    @Command("line-item delete")
    public void lineItemDelete(@Option("id") final String id) { ... }
}
```

This produces the same hierarchy as the separate-class example. The two approaches
mix freely — some sub-commands defined inline via method paths, others contributed
by separate classes.

Both class and method paths can be multi-word. `@Command("app server")` on the class
with `@Command("config set")` on a method produces `app server config set`.

#### Intermediate Group Auto-Creation

Intermediate groups are created automatically (mkdir -p style). If
`@Command("quote line-item")` is declared but no class declares `@Command("quote")`,
the `quote` group is auto-created with no description. If a class later provides
`@Command("quote")` with a description, it merges in.

#### Collision Detection

A name cannot be both a leaf command and a group containing sub-commands. If a class
has a method named `setting` (producing a leaf command) and a separate class declares
`@Command("config setting")` (producing a group), the framework throws an error.

Help navigates deep groups: `help quote`, `help quote line-item`,
`help quote line-item create`.

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

Annotate commands returning collections with `@Table` for automatic tabular output.
For full details on borders, TableOptions, programmatic table building, and cell formatting, read `references/tables.md`.

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

Register custom parameter types with `@Editor` using `AbstractConverter` or `PropertyEditorSupport`.
For full details on editors, the type conversion chain, domain wrapper types, and Bean Validation, read `references/types.md`.

## Type Conversion

Crest auto-converts CLI strings to Java types via `PropertyEditor`, enum matching, `Constructor(String)`, or static factory methods.
For the full conversion chain, built-in types, and the domain wrapper type pattern, read `references/types.md`.

## Help and Documentation

Crest provides a built-in `help` command and generates man-page-style documentation from javadoc.
For full details on help listings, man pages, option descriptions, and terminal formatting, read `references/help.md`.

## Interceptors

Define cross-cutting concerns with `@CrestInterceptor` and attach via `@Command(interceptedBy)` or custom annotations.
For full details on interceptor patterns, CrestContext, and custom interceptor annotations, read `references/interceptors.md`.

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
