---
name: pixie
description: "Reference for org.tomitribe.pixie lightweight dependency injection, configuration, and event library. TRIGGER when: code imports from org.tomitribe.pixie, uses @Param/@Component/@Default/@Event/@Observes/@Factory/@Builder annotations, or user needs constructor injection with properties-based configuration. DO NOT TRIGGER when: working with CDI, Spring, or Guice."
---

# Pixie - Lightweight Dependency Injection, Configuration & Events

Tiny 100KB Java library for constructor injection, properties-based configuration, and an observer-pattern event system.
Use Pixie anywhere you would use reflection to instantiate a Java object.

**Package:** `org.tomitribe.pixie`

## Maven Coordinates

```xml
<groupId>org.tomitribe.pixie</groupId>
<artifactId>pixie</artifactId>
<version>2.12</version>
```

## Annotations

All annotations are in `org.tomitribe.pixie`. Every constructor parameter Pixie uses must be annotated with one of these:

| Annotation   | Target    | Purpose                                                        |
|--------------|-----------|----------------------------------------------------------------|
| `@Param`     | PARAMETER | Maps a constructor parameter to a config property              |
| `@Default`   | PARAMETER | Provides a default value if the property is missing            |
| `@Component` | PARAMETER | Injects a dependent object built by or given to Pixie `System` |
| `@Nullable`  | PARAMETER | Allows a parameter to be `null` if not configured              |
| `@Name`      | PARAMETER | Injects the component's name from config                       |
| `@Event`     | PARAMETER | Injects a `Consumer<T>` to fire events                         |
| `@Observes`  | PARAMETER | Marks a method parameter as an event listener                  |
| `@Factory`   | METHOD    | Marks a static factory method for object creation              |
| `@Builder`   | METHOD    | Marks a static method returning a builder class                |

Every constructor parameter must have exactly one of `@Param`, `@Component`, `@Name`, or `@Event`.
`@Default` and `@Nullable` are modifiers used alongside `@Param` or `@Component`.

---

## Configuration via Properties

Components are declared using `new://` syntax. Properties are set as `name.param = value`. Component references use `@` prefix.

```properties
jane = new://org.example.Person
jane.age = 37
jane.address = @home

home = new://org.example.Address
home.street = 820 Roosevelt Street
home.city = River Falls
home.state = WI
home.zipcode = 54022
home.country = USA
```

### Declaration Order Matters

The order components are declared in the properties file is preserved. This matters for by-type resolution — when multiple components match, the **first declared** match is selected.

### Case Insensitivity

All property keys are case insensitive — component names, param names, and `@` references are all matched without regard to case. `user.name`, `User.Name`, and `USER.NAME` are equivalent.

### Strict Validation

If a property is specified in the configuration but does not match any constructor parameter, Pixie throws `UnknownPropertyException` at startup. This prevents typos or stale properties from going unnoticed.

### Loading Properties

```java
final Properties properties = new Properties();
properties.load(...);

final System system = new System(properties);
final Person person = system.get(Person.class);
```

---

## Annotating Classes

```java
public class Person {
    private final String name;
    private final int age;
    private final Address address;

    public Person(@Name final String name,
                  @Param("age") final int age,
                  @Param("address") @Component final Address address) {
        this.name = name;
        this.age = age;
        this.address = address;
    }
}

public class Address {
    public Address(@Param("street") final String street,
                   @Param("city") final String city,
                   @Param("state") final State state,
                   @Param("zipcode") final int zipcode,
                   @Param("country") @Default("USA") final String country) {
        // ...
    }
}
```

---

## `@Param` — Property Binding and Type Conversion

Binds a constructor parameter to a configuration property. All values originate as strings and are converted automatically.

### Conversion Chain (first match wins)

1. Registered `java.beans.PropertyEditor`
2. `Enum.valueOf()` — case-insensitive (exact, then uppercase, then lowercase)
3. `Constructor(String)` — any public constructor taking a single `String`
4. `Constructor(CharSequence)` — any public constructor taking `CharSequence`
5. Public static factory method — any public static method taking `String` and returning the type (`valueOf`, `of`, `parse`, `from`, or any name)

### Built-in Types

| Category | Types |
|----------|-------|
| Primitives & wrappers | `byte`, `short`, `int`, `long`, `float`, `double`, `boolean`, `char` and boxed |
| Strings | `String`, `CharSequence` |
| Enums | Any enum type (case-insensitive matching) |
| Files & paths | `java.io.File` |
| Network | `java.net.URI`, `java.net.URL` |
| Time | `java.util.concurrent.TimeUnit` |
| tomitribe-util | `Duration` (e.g., `"30 seconds"`, `"5m"`), `Size` (e.g., `"10mb"`, `"2.5 gb"`) |

### Custom Types

Any class with a `public Constructor(String)` automatically works:

```java
public class EmailAddress {
    public EmailAddress(final String value) {
        if (!value.contains("@")) throw new IllegalArgumentException("Invalid: " + value);
        this.value = value;
    }
}
```

```java
public NotificationService(@Param("admin") final EmailAddress admin) { ... }
```

```properties
notifications = new://org.example.NotificationService
notifications.admin = admin@example.com
```

---

## `@Component` — Dependency Injection

Injects a dependent object. Resolution works in several ways.

### By Name

Set the property value to `@` followed by the component name:

```properties
cart = new://org.example.ShoppingCart
cart.processor = @stripe

stripe = new://org.example.StripeProcessor
stripe.apiKey = sk_live_abc123
```

```java
public ShoppingCart(@Param("processor") @Component
                    final PaymentProcessor processor) { ... }
```

Use named references when multiple components implement the same interface and you need a specific one:

```properties
orderCart = new://org.example.ShoppingCart
orderCart.processor = @stripe

donationCart = new://org.example.ShoppingCart
donationCart.processor = @paypal
```

### By Type

When no `@Param` value is given, Pixie finds a matching component by type. A component matches if it is **assignable** to the parameter type (same rule as `instanceof`). When multiple match, the **first declared** component wins.

```properties
# StripeProcessor is the default (declared first)
stripe = new://org.example.StripeProcessor
stripe.apiKey = sk_live_abc123

paypal = new://org.example.PaypalProcessor
paypal.clientId = AaBb123

# Gets StripeProcessor automatically (first match by type)
cart = new://org.example.ShoppingCart
```

A `ConstructionFailedException` is thrown if no matching component is found.

### Generic Type Narrowing (v2.12)

When a `@Component` parameter has generic type arguments, Pixie narrows matching to only components whose resolved generics are compatible. Supports wildcards, mixed generic resolution, and nested parameterized bounds.
For full details, examples, and rules, read `references/generics.md`.

### Collection Injection

A `@Component` parameter can be any `Collection` type to inject multiple components at once.

| Parameter Type | Default Implementation |
|---------------|----------------------|
| `List<T>` | `ArrayList` |
| `Set<T>` | `LinkedHashSet` (preserves insertion order) |
| `Queue<T>` | `ArrayDeque` |
| `Collection<T>` | `ArrayList` |

#### Collect All by Type

When no value is specified, Pixie collects **all** components of the matching type:

```java
public class Pipeline {
    public Pipeline(@Param("handlers") @Component
                    final List<Handler> handlers) {
        // All Handler instances in the system
    }
}
```

#### Select Specific by Name

List component names with `@` references separated by spaces:

```properties
pipeline = new://org.example.Pipeline
pipeline.handlers = @handlerA @handlerB @handlerC
```

#### Generic Filtering on Collections

When the collection element type has generic type arguments, only matching components are collected. Raw collection types collect all implementations.
For full details and examples, read `references/generics.md`.

### Pre-built Instances

Objects can be added directly to the System:

```java
final System system = new System();
system.add("home", new Address("820 Roosevelt Street",
        "River Falls", State.WI, 54022, "USA"));
system.load(properties);
```

Added without a name, instances are resolved by type. Useful for third-party objects, runtime values, and test doubles.

---

## Producers — How Components Are Created

Three production strategies: Constructor (default), `@Factory` (static factory method), and `@Builder` (builder pattern).
For full details, examples, and rules for each strategy, read `references/producers.md`.

---

## Events

Fire events with `@Event Consumer<T>`, observe with `@Observes`. Supports polymorphic observation, most-specific matching, `BeforeEvent<T>`/`AfterEvent<T>` lifecycle wrappers, and built-in system events (`PixieLoad`, `PixieClose`, `ComponentAdded`, `ObserverFailed`, etc.).
For full details, examples, and the built-in events table, read `references/events.md`.

---

## System API

### Constructors

```java
new System()                                          // empty system
new System(Properties properties)                     // load from properties
new System(boolean warnOnUnusedProperties)            // empty with warn mode
new System(Properties properties, boolean warn)       // load with warn mode
```

### Loading & Retrieving Components

```java
void           load(Properties properties)             // load additional properties
<T> T          get(Class<T> type)                      // get by type
<T> T          get(Class<T> type, String name)         // get by type and name
<T> List<T>    getAll(Class<T> type)                   // get all matching type
List<Object>   getAnnotated(Class<? extends Annotation> type)  // get by annotation
<T> void       add(String name, T value)               // add pre-built component by name
<T> void       add(T value)                            // add pre-built component by type
```

### Events

```java
<E> E              fireEvent(E event)                  // fire event, returns it
<E> Consumer<E>    consumersOf(Class<E> eventClass)    // get consumer for event type
boolean            addObserver(Object observer)         // register observer
boolean            removeObserver(Object observer)      // unregister observer
```

### Lifecycle

```java
void close()   // fires PixieClose event, implements Closeable
```

---

## Builder APIs

`System.builder()` builds a full System in code without properties files. `Instance.builder()` builds a single object without a full System.
For full details, method signatures, and examples, read `references/builders.md`.

---

## Testing

Every Pixie component can be instantiated with `new` — no framework needed. `@Event Consumer<T>` parameters accept lambdas, observer methods are regular methods callable directly, and `System.builder()` supports full integration tests with test doubles via `add()`.
For full details and examples, read `references/testing.md`.

---

## Key Exceptions

All exceptions are in `org.tomitribe.pixie.comp`:

- `MissingRequiredParamException` — required `@Param` not in config
- `UnknownPropertyException` — config property not matching any constructor parameter
- `ConstructionFailedException` — component construction failed (wraps cause)
- `InvalidConstructorException` — constructor has unannotated parameters
- `CircularReferencesException` — circular component dependencies detected
- `NamedComponentNotFoundException` — `@Component` reference points to nonexistent name
- `MissingComponentDeclarationException` — `comp()` supplied but class has no matching `@Component`
- `AmbiguousConstructorException` — multiple constructors and Pixie can't pick one
- `InvalidParamValueException` — value can't be converted to the parameter type
