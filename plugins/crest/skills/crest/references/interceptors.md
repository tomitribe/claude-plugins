# Interceptors

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

## Attaching Interceptors

**Direct attachment** via `@Command(interceptedBy = ...)`:

```java
@Command(interceptedBy = TimingInterceptor.class)
public String deploy(...) { ... }
```

## Custom Interceptor Annotations

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
