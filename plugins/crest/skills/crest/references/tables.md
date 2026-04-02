# Table Formatting

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

## Border Styles

`Border.asciiCompact` (default), `asciiDots`, `asciiSeparated`, `githubMarkdown`,
`mysqlStyle`, `unicodeDouble`, `unicodeSingle`, `unicodeSingleSeparated`,
`whitespaceCompact`, `whitespaceSeparated`, `tsv`, `csv`,
`reStructuredTextGrid`, `reStructuredTextSimple`, `redditMarkdown`

## TableOptions

Add `TableOptions` as a command parameter to let users override table settings at runtime:

```java
@Command
@Table(fields = "name state schedule", sort = "name")
public Stream<Job> list(final Config config, final TableOptions tableOptions) { ... }
```

CLI usage: `list --table-border=unicodeSingle --no-table-header --table-sort=state --tsv`

## Programmatic Table Building

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

## Table Cell Formatting

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
