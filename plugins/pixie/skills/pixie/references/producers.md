# Producers — How Components Are Created

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
