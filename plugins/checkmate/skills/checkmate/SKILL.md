# Checkmate - Fluent Validation Library

Java library for validating runtime conditions with a fluent API, formatted aligned output, and automatic short-circuiting after failures. Ideal for configuration validation, deployment assertions, and CLI diagnostics.

**Package:** `org.tomitribe.checkmate`

## Maven Coordinates

```xml
<groupId>org.tomitribe</groupId>
<artifactId>checkmate</artifactId>
<version>1.1-SNAPSHOT</version>
```

## Quick Start

```java
final Checks checks = Checks.builder()
        .print(System.out, 50)
        .build();

checks.object("JAVA_HOME", new File("/opt/java"))
      .check("exists", File::exists)
      .check("is directory", File::isDirectory)
      .check("is readable", File::canRead);
```

Output:

```
JAVA_HOME exists . . . . . . . . . . . . . . .  PASS
JAVA_HOME is directory . . . . . . . . . . . .  PASS
JAVA_HOME is readable. . . . . . . . . . . . .  PASS
```

## Creating a Checks Instance

```java
// With console output (dot-padded to column width)
Checks checks = Checks.builder()
        .print(System.out, 50)
        .build();

// Silent mode (no output)
Checks checks = Checks.builder().build();

// Custom logger
Checks checks = Checks.builder()
        .logger(myCustomLogger)
        .build();

// Multiple loggers
Checks checks = Checks.builder()
        .logger(new Slf4jLogger())
        .print(System.out, 50)
        .build();
```

## Checking Styles

### Style 1: Manual Check

```java
final Check check = checks.check("File exists");
if (file.exists()) {
    check.pass();
} else {
    check.fail();
}
```

### Style 2: Lambda Checks

```java
checks.check("File exists", () -> file.exists());
checks.check("Optional config", () -> config.isPresent(), WhenFalse.WARN);
```

### Style 3: Fluent Object Checks

Check multiple conditions on a single object. After the first failure, remaining checks are automatically skipped.

```java
checks.object("JAVA_HOME", new File("/opt/java"))
      .check("exists", File::exists)
      .check("is directory", File::isDirectory)
      .check("is readable", File::canRead)
      .check("is writable", File::canWrite);
```

Output when directory doesn't exist:

```
JAVA_HOME exists . . . . . . . . . . . . . . .  FAIL
JAVA_HOME is directory . . . . . . . . . . . .  SKIP
JAVA_HOME is readable. . . . . . . . . . . . .  SKIP
JAVA_HOME is writable. . . . . . . . . . . . .  SKIP
```

### Style 4: Get Or Throw

Get the validated object or throw if any check failed:

```java
final File dir = checks.object("JAVA_HOME", new File("/opt/java"))
        .check("exists", File::exists)
        .check("is directory", File::isDirectory)
        .getOrThrow(() -> new IllegalStateException("Invalid JAVA_HOME"));
```

### Style 5: Map to Sub-Objects

Navigate into sub-objects with `.map()`. If a prior check failed, the map function is never called.

```java
final File bin = checks.object("JAVA_HOME", dir)
        .check("exists", File::exists)
        .check("is directory", File::isDirectory)
        .map("bin directory", file -> new File(file, "bin"))
        .check("exists", File::exists)
        .check("is executable", File::canExecute)
        .getOrThrow(() -> new RuntimeException("Invalid JAVA_HOME/bin/"));
```

### Style 6: Fallbacks with .or()

Try alternative values when checks fail:

```java
final File javaHome = checks.object("JAVA_HOME", new File("/opt/java"))
    .check("exists", File::exists)
    .check("is directory", File::isDirectory)
.or("JAVA_HOME (fallback #1)", new File("/usr/lib/jvm/java-11-openjdk"))
    .check("exists", File::exists)
    .check("is directory", File::isDirectory)
.or("JAVA_HOME (fallback #2)", new File("/usr/java/latest"))
    .check("exists", File::exists)
    .check("is directory", File::isDirectory)
.getOrThrow(() -> new IllegalStateException("No valid JAVA_HOME found"));
```

The `.or()` fallback is only used if all checks on the previous object failed. If the first object passes, fallbacks are skipped entirely.

## Warnings

Use `WhenFalse.WARN` for non-critical checks. Warnings short-circuit like failures but log as `WARN` instead of `FAIL`:

```java
checks.check("Optional config present", () -> config.exists(), WhenFalse.WARN);

checks.object("Config", configFile)
      .check("exists", File::exists)
      .check("is writable", File::canWrite, WhenFalse.WARN);
```

## Result Inspection

```java
// Get overall result
boolean allPassed = checks.result();

// Throw if any check failed
checks.orThrow(() -> new IllegalStateException("Validation failed"));

// Throw from object checks
checks.object("DB", connection)
      .check("is connected", Connection::isValid)
      .orThrow(() -> new RuntimeException("Database unavailable"));
```

## Check Interface

Result reporting contract used by loggers:

```java
public interface Check {
    void pass();
    void fail();
    void fail(String reason);
    void warn();
    void warn(String reason);
    void skip();
    void error(String reason);
}
```

## Custom Loggers

Implement `CheckLogger` for custom output:

```java
public interface CheckLogger {
    Check log(String name);
}
```

Example:

```java
public class Slf4jLogger implements CheckLogger {
    private final Logger logger = LoggerFactory.getLogger("checkmate");

    @Override
    public Check log(final String name) {
        return new Check() {
            public void pass() { logger.info("{} PASS", name); }
            public void fail() { logger.error("{} FAIL", name); }
            public void warn() { logger.warn("{} WARN", name); }
            public void skip() { logger.debug("{} SKIP", name); }
            public void error(String reason) { logger.error("{} ERROR: {}", name, reason); }
            // ... remaining methods
        };
    }
}
```

## ObjectChecks API

```java
<T> ObjectChecks<T> object(String description, T object)
<T> ObjectChecks<T> object(String description, Supplier<T> supplier)

// ObjectChecks methods:
ObjectChecks<T> check(String description, Function<T, Boolean> check)
ObjectChecks<T> check(String description, Function<T, Boolean> check, WhenFalse whenFalse)
<R> ObjectChecks<R> map(String description, Function<? super T, ? extends R> mapper)
<R> ObjectChecks<R> map(Function<? super T, ? extends R> mapper)
ObjectChecks<T> or(String description, T object)
ObjectChecks<T> or(String description, Supplier<T> supplier)
<X extends Throwable> T getOrThrow(Supplier<? extends X> exceptionSupplier)
<X extends Throwable> ObjectChecks<T> orThrow(Supplier<? extends X> exceptionSupplier)
boolean result()
```

## Key Behaviors

- **Short-circuiting**: After the first `FAIL` or `WARN`, remaining checks on that object are logged as `SKIP`
- **Lazy evaluation**: `Supplier`-based constructors defer object creation until needed
- **Safe mapping**: `.map()` functions are not called if prior checks failed (no NPE risk)
- **Error handling**: Exceptions in check predicates are caught and logged as `ERROR` with class and message
- **Label concatenation**: Object description is prepended to check descriptions for hierarchical output
