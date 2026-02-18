# Java `final` Keyword Conventions

When writing or modifying Java code in this project, apply `final` according to these conventions.

## Method Parameters — Always `final`

Every method parameter must be `final`. This includes constructors, lambda parameters, and catch blocks.

```java
public String download(final S3File file) { ... }
public static Token decrypt(final String base64Token) { ... }
public void upload(final String customerId, final LocalDate expiration) { ... }
```

## Local Variables — Always `final`

Every local variable must be `final`. The only exception is a variable that is intentionally reassigned (e.g., a loop accumulator).

```java
final LocalDate now = LocalDate.now();
final String[] parts = decrypted.split(":");
final File target = new File(destination, name);
```

## Instance Fields — `final` for immutability

Fields in Lombok `@Data`/`@Builder` classes are `final` by default, producing immutable objects. Only omit `final` when the field must be mutable (e.g., a counter or state tracker).

```java
@Data
@Builder(builderClassName = "Builder")
public class Download {
    private final File destination;   // immutable
    private final PrintStream out;    // immutable
    private int count;                // intentionally mutable
}
```

## Static Fields — Always `final`

All static fields are constants and must be `final`.

```java
private static final Logger LOGGER = Logger.getLogger(Signatures.class.getName());
private static final String ALGORITHM = "AES";
```

## Enum Fields — Always `final`

Enum instance fields are always `final`, and enum constructor parameters follow the same rules as method parameters.

```java
enum Action {
    DOWNLOAD("Downloading", "Downloaded");

    private final String presentProgressive;
    private final String past;

    Action(final String presentProgressive, final String past) {
        this.presentProgressive = presentProgressive;
        this.past = past;
    }
}
```

## Class Declarations — Not typically `final`

Classes are generally **not** marked `final`. The exception is utility classes with only static methods.

## Method Declarations — Not typically `final`

Methods are generally **not** marked `final`. This is not part of the project convention.
