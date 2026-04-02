# Collection Utilities, Options, ObjectMap, and SuperProperties

## Collection Utilities

### AbstractIterator

Base class for custom iterators. Implement `advance()` returning null when done.

```java
class MyIterator extends AbstractIterator<String> {
    protected String advance() {
        // return next item or null
    }
}
```

### FilteredIterator / FilteredIterable

```java
Iterator<String> filtered = new FilteredIterator<>(iterator, s -> s.startsWith("A"));
Iterable<String> filtered = new FilteredIterable<>(iterable, s -> s.length() > 3);
```

### CompositeIterator / CompositeIterable

Chain multiple iterators/iterables:

```java
Iterator<String> combined = new CompositeIterator<>(iteratorOfIterators);
```

### Suppliers

Convert between Suppliers, Iterators, and Streams:

```java
Stream<Item> stream = Suppliers.asStream(supplier);         // Supplier -> Stream
Iterator<Item> iter = Suppliers.asIterator(supplier);       // Supplier -> Iterator
Stream<Item> stream = Suppliers.asStream(iterator);         // Iterator -> Stream
Supplier<T> memo = Suppliers.singleton(expensiveSupplier);  // memoizing
```

---

## Options — Strongly-Typed Properties

Properties wrapper with type-safe getters, hierarchy, and enum support.

```java
Options opts = new Options(properties);
Options child = new Options(childProperties, opts);  // parent fallback

String val = opts.get("key", "default");
int port = opts.get("port", 8080);
long timeout = opts.get("timeout", 30000L);
boolean debug = opts.get("debug", false);
Class<?> cls = opts.get("driver", Driver.class);

// Enum support (case-insensitive)
MyEnum mode = opts.get("mode", MyEnum.DEFAULT);

// Enum sets with ALL/NONE keywords
Set<Feature> features = opts.getAll("features", Feature.class);
// "ALL" returns all enum values, "NONE" returns empty set
// "A, B, C" returns specific values

boolean has = opts.has("key");
```

---

## ObjectMap — Map View of Object Properties

Expose an object's JavaBean properties (or public fields, or Record components) as a `Map<String, Object>`.

```java
ObjectMap map = new ObjectMap(myObject);
Object name = map.get("name");             // calls getName()
map.put("name", "newValue");               // calls setName("newValue")
boolean has = map.containsKey("name");
Set<Entry<String, Object>> entries = map.entrySet();
```

Supports: public fields, JavaBean getters/setters (`get*`, `is*`, `find*`), Java Records (14+). Values are auto-converted via `Converter` on `put()`.

### Member Interface

```java
ObjectMap.Member extends Map.Entry<String, Object>, AnnotatedElement {
    Class<?> getType();
    boolean isReadOnly();
}
```

---

## SuperProperties — Enhanced Properties

Extends `java.util.Properties` with:
- **Ordered keys** (LinkedHashMap-backed)
- **Per-property comments** -- preserved across load/save
- **Per-property attributes** -- key-value metadata on each property
- **Case-insensitive lookup** option
