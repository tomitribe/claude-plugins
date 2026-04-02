# Help and Documentation

Crest provides a built-in `help` command and generates man-page-style documentation automatically.

## Built-in Help Command

Registered automatically. No setup required.

```bash
myapp help                          # Lists all commands with descriptions
myapp help commit                   # Full man page for "commit"
myapp help config set               # Man page for sub-command "set" in group "config"
myapp help config setting add       # Man page for "add" in nested group "config setting"
```

## Command Descriptions in Listings

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

## Command Listing Format

The listing is formatted as: 3 spaces + command name (left-aligned, padded to longest name + 3 spaces) + description.
The padding is computed dynamically from the longest command name in the group.

## Description Resolution for Groups and Overloads

**Command groups** (`CmdGroup`): When multiple classes contribute to the same group via
`@Command("sameName")`, the description comes from whichever class has a non-empty
`@Command(description)`. All contributing classes are checked, so it doesn't matter
which class is registered first.

**Overloaded commands** (`OverloadedCmdMethod`): When multiple methods share the same
command name but have different signatures, the description comes from whichever
overload has a non-null description. All overloads are searched.

## Man Page Generation

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

## @Command `usage` Parameter

Overrides the auto-generated SYNOPSIS line. If omitted, crest builds it from the
method signature as `commandName [options] arg1 arg2...`.

```java
@Command(value = "commit", usage = "commit [options] <message> <file>")
public void commit(...) { }
```

## Option Description Sources (Priority Order)

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

## @Exit with Help

When `help = true`, the error message is printed followed by the command's help text:

```java
@Exit(value = 400, help = true)
public class MissingArgumentException extends IllegalArgumentException { ... }
```

Used internally so users see correct usage on parse errors.

## Terminal Formatting

Man pages are formatted with:
- Text wrapping to terminal width
- ANSI color highlighting for `--flags` and `` `code` ``
- Justified text with margin padding
- Pager support (pipes through `less` if available)
