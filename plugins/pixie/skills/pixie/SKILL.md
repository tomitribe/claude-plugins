---
description: "Reference for org.tomitribe.pixie lightweight dependency injection, configuration, and event library. TRIGGER when: code imports from org.tomitribe.pixie, uses @Param/@Component/@Default/@Event/@Observes annotations, or user needs constructor injection with properties-based configuration. DO NOT TRIGGER when: working with CDI, Spring, or Guice."
---

# Pixie - Lightweight Dependency Injection, Configuration & Events

Tiny 100KB Java library for constructor injection, properties-based configuration, and an observer-pattern event system.
Use Pixie anywhere you would use reflection to instantiate a Java object.

**Package:** `org.tomitribe.pixie`

## Maven Coordinates

```xml
<groupId>org.tomitribe.pixie</groupId>
<artifactId>pixie</artifactId>
<version>2.0</version>
```

## Constructor Annotations

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

## Annotating Classes for Pixie

Every constructor parameter must have exactly one of `@Param`, `@Component`, `@Name`, or `@Event`.
`@Default` and `@Nullable` are modifiers used alongside `@Param` or `@Component`.

```java
import org.tomitribe.pixie.Component;
import org.tomitribe.pixie.Default;
import org.tomitribe.pixie.Name;
import org.tomitribe.pixie.Param;

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
    private final String street;
    private final String city;
    private final State state;
    private final int zipcode;
    private final String country;

    public Address(@Param("street") final String street,
                   @Param("city") final String city,
                   @Param("state") final State state,
                   @Param("zipcode") final int zipcode,
                   @Param("country") @Default("USA") final String country) {
        this.street = street;
        this.city = city;
        this.state = state;
        this.zipcode = zipcode;
        this.country = country;
    }
}
```

## `@Param` — Property Binding

Binds a constructor parameter to a configuration property. Any Java type that can be constructed from a `String` is supported. Pixie looks for:

1. A public constructor with a single `String` parameter
2. A public static method with a single `String` parameter returning the type

```java
public class User {
    public User(@Param("username") final String username,
                @Param("age") final int age) { ... }
}
```

Maps to properties:

```properties
user=new://org.example.User
user.username=alice
user.age=30
```

## `@Default` — Default Values

Provides a fallback value when a property is not configured. Works with both `@Param` and `@Component`.

```java
public Address(@Param("country") @Default("USA") final String country) { ... }
```

When used on `@Component`, it specifies the default component name to inject.

## `@Component` — Dependency Injection

Injects a dependent object. Resolution works two ways:

**By name** — when a `@Param` value is provided with `@` prefix:

```properties
cart=new://org.example.ShoppingCart
cart.processor=@stripe

stripe=new://org.example.StripeProcessor
```

```java
public ShoppingCart(@Param("processor") @Component final PaymentProcessor processor) { ... }
```

**By type** — when no `@Param` value is given, Pixie finds a matching object by type. If multiple exist, they are sorted descending by name and the first is picked:

```properties
cart=new://org.example.ShoppingCart
```

A `ConstructionFailedException` is thrown if no matching object is found.

### Adding Pre-built Components

Objects can be added directly to the System before loading properties:

```java
final System system = new System();
system.add("home", new Address("820 Roosevelt Street", "River Falls", State.WI, 54022, "USA"));
system.load(properties);
```

## `@Nullable` — Optional Parameters

Allows a parameter to be `null` when not configured, instead of throwing an error:

```java
public Notification(@Param("message") final String message,
                    @Nullable @Param("footer") final String footer) { ... }
```

## `@Name` — Component Name Injection

Injects the component's name from the configuration:

```java
public Service(@Name final String serviceName) { ... }
```

If configured as `myService=new://com.example.Service`, the constructor receives `"myService"`.

## `@Event` — Event Firing

Injects a `Consumer<T>` that fires events to all observers in the System:

```java
public class OrderService {
    private final Consumer<OrderPlaced> event;

    public OrderService(@Event final Consumer<OrderPlaced> event) {
        this.event = event;
    }

    public void placeOrder(final String orderId) {
        event.accept(new OrderPlaced(orderId));
    }
}
```

## `@Observes` — Event Listening

Marks a method parameter as an event listener. The method is called when a matching event is fired:

```java
public class OrderListener {
    public void onOrderPlaced(@Observes final OrderPlaced event) {
        System.out.println("Order placed: " + event.getOrderId());
    }
}
```

Observation is polymorphic — you can observe by any assignable type, including `Object` to receive all events:

```java
public void onAny(@Observes final Object event) { ... }
```

## `@Factory` — Static Factory Methods

Marks a static method as the factory for creating the object. The method's parameters follow the same annotation rules:

```java
public class Connection {
    @Factory
    public static Connection create(@Param("url") final String url,
                                     @Param("timeout") @Default("30") final int timeout) {
        return new Connection(url, timeout);
    }
}
```

## `@Builder` — Builder Pattern Support

Marks a static method that returns a builder object. Pixie calls the builder's `build()` method after setting properties:

```java
public class Config {
    @Builder
    public static ConfigBuilder builder() {
        return new ConfigBuilder();
    }
}
```

## Configuration via Properties

Components are declared using `new://` syntax. Properties are set as `name.param=value`. Component references use `@` prefix.

```properties
jane=new://org.example.Person
jane.age=37
jane.address=@home

home=new://org.example.Address
home.street=820 Roosevelt Street
home.city=River Falls
home.state=WI
home.zipcode=54022
home.country=USA
```

### Configuration Rules

- **Case insensitive** — `user.name`, `User.Name`, and `USER.NAME` are equivalent
- **Strict validation** — extra properties not matching any constructor parameter throw `UnknownPropertyException` at startup
- **Warn mode** — use `warnOnUnusedProperties` to log warnings instead of throwing exceptions

## System API

### Constructors

```java
new System()                                          // empty system
new System(Properties properties)                     // load from properties
new System(boolean warnOnUnusedProperties)             // empty with warn mode
new System(Properties properties, boolean warn)        // load with warn mode
```

### Loading & Retrieving Components

```java
void           load(Properties properties)             // load additional properties
<T> T          get(Class<T> type)                      // get by type
<T> T          get(Class<T> type, String name)         // get by type and name
<T> List<T>    getAll(Class<T> type)                   // get all matching type
List<Object>   getAnnotated(Class<? extends Annotation> type)  // get by annotation
<T> void       add(String name, T value)               // add pre-built component
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

## Built-in Events

| Event              | Fired When                         |
|--------------------|------------------------------------|
| `PixieLoad`        | After `system.load()` completes    |
| `PixieClose`       | When `system.close()` is called    |
| `ComponentAdded`   | A component is added to the System |
| `ComponentRemoved` | A component is removed             |
| `ObserverAdded`    | An observer is registered          |
| `ObserverRemoved`  | An observer is unregistered        |
| `ObserverFailed`   | An observer method threw            |
| `ObserverNotFound` | No observers found for an event    |
| `BeforeEvent`      | Before an event is dispatched      |
| `AfterEvent`       | After an event is dispatched       |

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
