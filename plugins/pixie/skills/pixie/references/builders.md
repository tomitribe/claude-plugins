# Builder APIs

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
