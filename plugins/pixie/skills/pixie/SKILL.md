---
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

When a `@Component` parameter has generic type arguments, Pixie narrows matching to only components whose resolved generics are compatible. Raw type parameters (no generics) match any implementation for backwards compatibility.

```java
public interface RequestHandler<I, O> {
    O handle(I input);
}

public class ApiGateway {
    public ApiGateway(@Param("handler") @Component
                      final RequestHandler<APIGatewayProxyRequestEvent,
                                           APIGatewayV2HTTPResponse> handler) {
        // Only RequestHandler implementations with matching type
        // arguments will be injected
    }
}
```

#### Wildcards

Wildcards follow standard Java assignability rules:

```java
// Matches any RequestHandler whose first type argument extends Number
@Component RequestHandler<? extends Number, ?> handler

// Matches any RequestHandler whose first type argument is a supertype of Integer
@Component RequestHandler<? super Integer, ?> handler

// Matches any RequestHandler regardless of type arguments
@Component RequestHandler<?, ?> handler
```

Nested parameterized bounds such as `? extends Comparable<String>` are supported.

#### Mixed Generic Resolution

Type arguments can come from multiple sources and are correctly stitched together — some from the producer declaration, others from the class hierarchy. For example, a factory returning `BooleanHandler<String>` where `BooleanHandler<I> implements RequestHandler<I, Boolean>` correctly resolves to `RequestHandler<String, Boolean>`.

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

When the collection element type has generic type arguments, only matching components are collected:

```java
public class CountHandler implements RequestHandler<String, Integer> { ... }
public class LengthHandler implements RequestHandler<String, Integer> { ... }
public class ValidHandler implements RequestHandler<String, Boolean> { ... }
public class FetchHandler implements RequestHandler<URI, String> { ... }

public class Pipeline {
    public Pipeline(@Param("handlers") @Component
                    final List<RequestHandler<String, Integer>> handlers) {
        // handlers contains CountHandler and LengthHandler only
        // ValidHandler and FetchHandler are excluded
    }
}
```

Raw collection types (`List<RequestHandler>`) collect all implementations. Wildcards work too:

```java
// Collects any RequestHandler whose input type extends Number
@Param("handlers") @Component List<RequestHandler<? extends Number, ?>> handlers
```

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

### Constructor (default)

The most common approach. Annotate a public constructor's parameters:

```java
public class Person {
    public Person(@Name final String name,
                  @Param("age") final int age,
                  @Param("address") @Component final Address address) {
        // ...
    }
}
```

Rules:
- Constructor must be **public**
- Every parameter must be annotated
- If multiple constructors exist, Pixie uses the fully annotated one

### `@Factory` — Static Factory Method

A public static method that Pixie calls to create the component. Useful when the constructor is private, when you need validation before construction, or when producing instances of a class you don't own.

**Factory in the same class:**

```java
public class Person {
    private Person(final String name, final Integer age, final Address address) { ... }

    @Factory
    public static Person create(@Name final String name,
                                @Param("age") @Nullable final Integer age,
                                @Param("address") @Component final Address address) {
        return new Person(name, age, address);
    }
}
```

**Factory in a separate class** — the properties reference the factory class:

```java
public class PersonFactory {
    @Factory
    public static Person create(@Name final String name,
                                @Param("age") @Nullable final Integer age,
                                @Param("address") @Component final Address address) {
        return new Person(name, age, address);
    }
}
```

```properties
jane = new://org.example.PersonFactory
jane.age = 37
jane.address = @home
```

The component is registered by the **return type** of the factory method, not the factory class:

```java
final Person jane = system.get(Person.class);
```

Rules:
- Method must be **public** and **static** and annotated with `@Factory`
- All parameters must be annotated with Pixie annotations
- Method name does not matter
- If a class has both `@Factory` and a constructor, `@Factory` takes priority

### `@Builder` — Builder Pattern

A `@Builder` method returns a builder object whose setter methods have Pixie-annotated parameters. Pixie calls setters, then `build()`.

```java
public class Person {
    @Builder
    public static PersonBuilder builder() {
        return new PersonBuilder();
    }

    public static class PersonBuilder {
        private String name;
        private Integer age;
        private Address address;

        public PersonBuilder name(@Name final String name) {
            this.name = name;
            return this;
        }

        public PersonBuilder age(@Param("age") @Nullable final Integer age) {
            this.age = age;
            return this;
        }

        public PersonBuilder address(@Param("address") @Component final Address address) {
            this.address = address;
            return this;
        }

        public Person build() {
            return new Person(name, age, address);
        }
    }
}
```

The builder class can also live in a separate class. Configuration is the same:

```properties
jane = new://org.example.Person
jane.age = 37
jane.address = @home
```

Rules:
- `@Builder` method must be **public** and **static**
- Builder class must have a public `build()` method with no parameters
- Each setter method has exactly **one** annotated parameter
- Setter method names do not matter — Pixie matches by annotation
- If both `@Factory` and `@Builder` exist, `@Factory` takes priority

Builders preserve generic type information from the `build()` return type, allowing builders with generic return types to participate in generics-aware component matching.

---

## Events

### Firing Events with `@Event`

Injects a `Consumer<T>` that dispatches events to all observers in the System:

```java
public class ShoppingCart {
    private final Consumer<OrderProcessed> orderProcessedEvent;

    public ShoppingCart(@Event final Consumer<OrderProcessed> orderProcessedEvent) {
        this.orderProcessedEvent = orderProcessedEvent;
    }

    public void order(final String orderId) {
        orderProcessedEvent.accept(new OrderProcessed(orderId));
    }
}
```

A component can inject multiple event consumers for different types:

```java
public OrderService(@Event final Consumer<OrderPlaced> orderPlaced,
                    @Event final Consumer<OrderShipped> orderShipped) { ... }
```

Events can also be fired directly on the System:

```java
system.fireEvent(new OrderProcessed("order123"));
```

### Observing Events with `@Observes`

Marks a method parameter as an event listener:

```java
public class EmailReceipt {
    public void onOrderProcessed(@Observes final OrderProcessed event) {
        sendEmail(event.getId());
    }
}
```

Multiple observers, multiple event types, multiple observer methods per component — all supported.

#### Polymorphic Observation

Observation is polymorphic — matches any event **assignable** to the parameter type:

```java
// Receives OrderProcessed and any subclass
public void onOrder(@Observes final OrderProcessed event) { ... }

// Receives every event in the system
public void onAny(@Observes final Object event) { ... }
```

#### Most-Specific Matching

When both a supertype and subtype observer exist, only the **most specific** match is called:

```java
public class Listener {
    // Called for Integer events
    public void onInteger(@Observes final Integer event) { ... }

    // Called for Long, Double, etc. — but NOT Integer
    public void onNumber(@Observes final Number event) { ... }
}
```

#### Exception Handling

Observer exceptions do not propagate to the event producer. Instead, Pixie fires an `ObserverFailed` event:

```java
public class ErrorHandler {
    public void onFailure(@Observes final ObserverFailed event) {
        log.error("Observer " + event.getMethod().getName() + " failed",
                  event.getThrowable());
    }
}
```

### BeforeEvent and AfterEvent

Pixie wraps every event dispatch in lifecycle wrappers:

```java
public class SecurityCheck {
    public void beforeOrder(@Observes final BeforeEvent<OrderProcessed> event) {
        // Runs before any @Observes OrderProcessed methods
        validatePermissions(event.getEvent());
    }
}

public class Metrics {
    public void afterOrder(@Observes final AfterEvent<OrderProcessed> event) {
        // Runs after all @Observes OrderProcessed methods
        recordMetric("order.processed");
    }
}
```

Execution order: `BeforeEvent<T>` → `T` observers → `AfterEvent<T>`

Type matching uses the generic argument — `BeforeEvent<Number>` fires before any `Integer`, `Long`, etc.

### Built-in Events

| Event | Fired When |
|-------|-----------|
| `PixieLoad` | After `system.load(properties)` completes. Contains the loaded `Properties`. |
| `PixieClose` | When `system.close()` is called. |
| `ComponentAdded<T>` | A component is added to the System. Contains the type and instance. |
| `ComponentRemoved<T>` | A component is removed from the System. |
| `ObserverAdded` | An observer is registered with the System. |
| `ObserverRemoved` | An observer is unregistered. |
| `BeforeEvent<T>` | Before an event of type `T` is dispatched. |
| `AfterEvent<T>` | After an event of type `T` has been dispatched. |
| `ObserverFailed` | An observer method threw an exception. Contains observer, method, event, and throwable. |
| `ObserverNotFound` | No observers exist for a fired event. |

`System` implements `Closeable`, so it works with try-with-resources:

```java
try (final System system = new System(properties)) {
    // PixieLoad fires after construction
} // PixieClose fires here
```

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

## System.builder() — Fluent Builder API

Build a System in code without properties files:

```java
final System system = System.builder()

        .definition(Person.class, "jane")
        .param("age", 37)
        .comp("address", "home")

        .definition(Address.class, "home")
        .param("street", "820 Roosevelt Street")
        .param("city", "River Falls")
        .param("state", "WI")
        .param("zipcode", "54022")

        .build();

final Person person = system.get(Person.class);
```

### SystemBuilder Methods

```java
SystemBuilder        add(Object value)                         // add pre-built component (by type)
SystemBuilder        add(String name, Object value)            // add pre-built component (by name)
SystemBuilder        warnOnUnusedProperties()                  // switch to warn mode
DefinitionBuilder    definition(Class<?> type)                 // define component (auto-named)
DefinitionBuilder    definition(Class<?> type, String name)    // define named component
```

### DefinitionBuilder Methods

```java
DefinitionBuilder    param(String name, String/int/boolean/double/long/... value)
DefinitionBuilder    comp(String name, Object value)           // set component ref by name
DefinitionBuilder    comp(Object value)                        // set component ref by type
DefinitionBuilder    comp(String name, String refName)         // set component ref to named component
DefinitionBuilder    optional(String name, Object value)       // set if declared, ignore otherwise
DefinitionBuilder    definition(Class<?> type)                 // chain next definition
DefinitionBuilder    definition(Class<?> type, String name)    // chain next named definition
System               build()                                   // build the System
```

---

## Instance.builder() — Single Object Builder

Build a single object without a full System:

```java
final Person person = Instance.builder(Person.class, "jane")
        .param("age", 37)
        .comp("address", new Address(...))
        .build();
```

### Instance.Builder Methods

```java
static <T> Builder<T>  builder(Class<T> type)
static <T> Builder<T>  builder(Class<T> type, String name)

Builder<T>  param(String name, String/int/boolean/double/long/... value)
Builder<T>  comp(String name, Object value)        // set component ref by name
Builder<T>  comp(Object value)                     // set component ref by type
Builder<T>  optional(Object value)                 // offer object by type (no error if unused)
Builder<T>  optional(String name, Object value)    // offer object by name (no error if unused)
Builder<T>  warnOnUnusedProperties()               // warn instead of throw for unused props
T           build()                                // build the instance
```

---

## Testing

### Plain Java — No Framework Needed

Every Pixie component can be instantiated with `new`:

```java
@Test
public void testPerson() {
    final Address home = new Address("820 Roosevelt Street",
            "River Falls", State.WI, 54022, "USA");
    final Person person = new Person("jane", 37, home);
    assertEquals("jane", person.getName());
}
```

#### Testing Events with Consumer

`@Event Consumer<T>` is just a constructor parameter. Pass a lambda:

```java
@Test
public void testOrderFiresEvent() {
    final List<OrderProcessed> firedEvents = new ArrayList<>();
    final ShoppingCart cart = new ShoppingCart(firedEvents::add);

    cart.order("order-123");

    assertEquals(1, firedEvents.size());
    assertEquals("order-123", firedEvents.get(0).getId());
}
```

#### Testing Observers

Observer methods are regular methods — call them directly:

```java
@Test
public void testEmailReceipt() {
    final EmailReceipt receipt = new EmailReceipt();
    receipt.onOrderProcessed(new OrderProcessed("order-456"));
    assertEquals(1, receipt.getOrdersProcessed().size());
}
```

### System.builder() — Integration Tests

For tests that exercise full Pixie wiring:

```java
@Test
public void testFullSystem() {
    final System system = System.builder()
            .definition(Person.class, "jane")
            .param("age", 37)
            .comp("address", "home")
            .definition(Address.class, "home")
            .param("street", "820 Roosevelt Street")
            .param("city", "River Falls")
            .param("state", "WI")
            .param("zipcode", "54022")
            .build();

    final Person jane = system.get(Person.class);
    assertEquals(37, jane.getAge());
}
```

#### Injecting Test Doubles

Use `add()` to substitute mocks or stubs:

```java
@Test
public void testWithMockProcessor() {
    final List<String> charged = new ArrayList<>();

    final System system = System.builder()
            .add("stripe", (PaymentProcessor) charged::add)
            .definition(ShoppingCart.class, "cart")
            .build();

    system.get(ShoppingCart.class).order("order-101");
    assertEquals(1, charged.size());
}
```

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
