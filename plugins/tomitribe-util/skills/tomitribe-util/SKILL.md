# tomitribe-util — Java Utility Library

Comprehensive utility library with zero runtime dependencies. Covers encoding/decoding, I/O, file operations, duration/size parsing, string templates, type conversion, collections, reflection, hashing, and more.

**Package:** `org.tomitribe.util` (and sub-packages)

## Maven Coordinates

```xml
<groupId>org.tomitribe</groupId>
<artifactId>tomitribe-util</artifactId>
<version>1.5.13-SNAPSHOT</version>
```

---

## Duration — Human-Readable Time Parsing

Parse and manipulate time durations from human-readable strings.

```java
Duration d = new Duration("10 seconds");
Duration d2 = new Duration("1 day and 5 hours");
Duration d3 = new Duration("30m");
Duration d4 = new Duration(500, TimeUnit.MILLISECONDS);

long ms = d.getTime(TimeUnit.MILLISECONDS);
Duration sum = d.add(d2);
Duration diff = d2.subtract(d);
```

**Accepted formats:** `10s`, `10 seconds`, `1 day and 5 hours`, `30m`, `500ms`, `2h, 30m`

**Unit aliases:** `ns`/`nano`/`nanoseconds`, `ms`/`milli`/`milliseconds`, `s`/`sec`/`seconds`, `m`/`min`/`minutes`, `h`/`hr`/`hours`, `d`/`day`/`days`

```java
long getTime()                      // raw value
long getTime(TimeUnit unit)         // converted
Duration add(Duration other)
Duration subtract(Duration other)
int compareTo(Duration other)
static Duration parse(String text)
```

Implements `Comparable<Duration>`. Registers a `PropertyEditor` automatically.

---

## Size — Human-Readable Data Size Parsing

Parse and manipulate data sizes from human-readable strings. Supports floating point.

```java
Size s = new Size("2.5 mb");
Size s2 = new Size("10kb");
Size s3 = new Size(1024, SizeUnit.BYTES);

long bytes = s.getSize(SizeUnit.BYTES);
Size converted = s.to(SizeUnit.KILOBYTES);
Size sum = s.add(s2);
```

**Unit aliases:** `b`/`byte`/`bytes`, `k`/`kb`/`kilobytes`, `m`/`mb`/`megabytes`, `g`/`gb`/`gigabytes`, `t`/`tb`/`terabytes`

```java
long getSize()                      // raw value
long getSize(SizeUnit unit)         // converted
Size to(SizeUnit unit)              // convert units
Size add(Size other)
Size subtract(Size other)
int compareTo(Size other)
static Size parse(String text)
```

### SizeUnit Enum

```java
SizeUnit.BYTES, KILOBYTES, MEGABYTES, GIGABYTES, TERABYTES

long toBytes(long size)
long toKilobytes(long size)
long toMegabytes(long size)
long toGigabytes(long size)
long toTerabytes(long size)
long convert(long sourceSize, SizeUnit sourceUnit)
```

---

## IO — Input/Output Operations

Comprehensive I/O utility with 50+ methods. Accepts `File`, `Path`, `URL`, `InputStream`, `OutputStream`.

### Reading

```java
String content = IO.slurp(file);           // read entire file
String content = IO.slurp(url);            // read from URL
byte[] bytes = IO.readBytes(file);         // read as bytes
byte[] bytes = IO.readBytes(inputStream);
Properties props = IO.readProperties(file);
String line = IO.readString(file);
```

### Writing

```java
IO.writeString(file, "content");
IO.writeString(path, "content");
IO.copy(inputStream, outputStream);
IO.copy(file, outputFile);
IO.copy(url, file);
IO.copyDirectory(sourceDir, destDir);
```

### Stream Creation

```java
InputStream in = IO.read(file);
InputStream in = IO.read(url);
InputStream in = IO.read("string content");
InputStream in = IO.read(byteArray);
OutputStream out = IO.write(file);
OutputStream out = IO.write(file, true);   // append mode
```

### Lines

```java
for (String line : IO.readLines(file)) { ... }     // lazy line iteration
```

### Zip

```java
ZipOutputStream zos = IO.zip(file);
ZipInputStream zis = IO.unzip(file);
```

### Utilities

```java
IO.close(closeable);                       // safe close with flush
IO.delete(file);                           // safe delete
IO.IGNORE_OUTPUT                           // null output stream constant
```

---

## Files — File/Directory Operations

```java
File f = Files.file("path", "to", "file.txt");       // construct path
List<File> javaFiles = Files.collect(dir, ".*\\.java$"); // recursive collect
boolean result = Files.visit(dir, filter, visitor);    // tree traversal

Files.exists(file);                        // assert exists (throws)
Files.dir(file);                           // assert is directory
Files.readable(file);                      // assert readable
Files.writable(file);                      // assert writable

File tmp = Files.tmpdir();                 // create temp directory
Files.mkdir(dir);                          // create single directory
Files.mkdirs(dir);                         // create directories
Files.mkparent(file);                      // create parent directories
Files.remove(dir);                         // delete recursively
Files.rename(src, dest);                   // rename
String human = Files.format(1048576.0);    // "1mb"
```

---

## Archive — In-Memory JAR Builder

Build JAR files programmatically with lazy evaluation.

```java
File jar = Archive.archive()
    .manifest("Main-Class", "com.example.Main")
    .add("data.txt", "content")
    .add("config.properties", new File("config.properties"))
    .add(MyClass.class)                    // add compiled class
    .addDir(new File("resources/"))        // add directory recursively
    .addJar(new File("lib.jar"))           // merge JAR contents
    .toJar();                              // generate JAR file

// Or extract to directory
File dir = archive.toDir(new File("output/"));
```

```java
static Archive archive()                   // factory
Archive manifest(String key, Object value)
Archive add(String name, String content)
Archive add(String name, byte[] bytes)
Archive add(String name, File file)
Archive add(String name, URL url)
Archive add(String name, Supplier<byte[]> supplier)  // lazy
Archive add(Class<?> clazz)                // add class + dependencies
Archive add(String name, Archive other)    // merge
Archive addDir(File dir)
Archive addJar(File jar)
File toJar()
File toJar(File dest)
File toDir(File dest)
File asJar()                               // unchecked version
File asDir()
```

---

## StringTemplate — Template Variable Substitution

Replace `{key}` placeholders in strings. Supports modifiers.

```java
StringTemplate template = new StringTemplate("Hello {name}!");
String result = template.format(Map.of("name", "World"));
// "Hello World!"

// With modifiers
new StringTemplate("{name.uc} {name.lc} {name.cc}");
// Modifiers: .uc (uppercase), .lc (lowercase), .cc (camelCase)

// Custom delimiters
new StringTemplate("Hello ${name}!", "${", "}");

// Extract keys
Set<String> keys = template.keys();

// Apply with function
String result = template.apply(key -> System.getProperty(key));
```

### Builder

```java
StringTemplate tmpl = StringTemplate.builder()
    .template("Hello {name}!")              // or .template(file) or .template(url)
    .delimiters("${", "}")
    .build();
```

### Applier

```java
String result = template.applier()
    .set("name", "World")
    .set("greeting", "Hello")
    .apply();
```

---

## Strings — Case Conversion

```java
Strings.lc("HELLO")          // "hello"
Strings.uc("hello")          // "HELLO"
Strings.ucfirst("hello")     // "Hello"
Strings.lcfirst("Hello")     // "hello"
Strings.camelCase("foo-bar") // "fooBar"
Strings.camelCase("foo_bar", "_") // "fooBar" (custom delimiter)
```

---

## Encoding/Decoding

### Hex

```java
String hex = Hex.toString(bytes);          // "48656c6c6f"
byte[] bytes = Hex.fromString("48656c6c6f");
```

### Base32

```java
String encoded = Base32.encode(bytes);
byte[] decoded = Base32.decode(encoded);
```

### Base58

```java
String encoded = Base58.encode(bytes);     // Bitcoin-style alphabet
byte[] decoded = Base58.decode(encoded);
```

### Base64

```java
byte[] encoded = Base64.encodeBase64(bytes);
byte[] encodedChunked = Base64.encodeBase64Chunked(bytes);  // 76-char lines
byte[] decoded = Base64.decodeBase64(encoded);
```

### Binary

```java
byte[] bytes = Binary.toBytes("01001000");
BitSet bits = Binary.toBitSet("01001000");
String binary = Binary.toString(bytes);
```

---

## Numeric Conversion

### Ints

```java
byte[] bytes = Ints.toBytes(42);           // 4-byte big-endian
int value = Ints.fromBytes(bytes);
String hex = Ints.toHex(42);
int value = Ints.fromHex("2a");
```

### Longs

```java
byte[] bytes = Longs.toBytes(42L);         // 8-byte big-endian
long value = Longs.fromBytes(bytes);
String hex = Longs.toHex(42L);
String b32 = Longs.toBase32(42L);
String b58 = Longs.toBase58(42L);
String b64 = Longs.toBase64(42L);
// And corresponding fromHex, fromBase32, fromBase58, fromBase64
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

## Escapes — String Unescaping

```java
String result = Escapes.unescape("Hello\\nWorld");   // "Hello\nWorld"
```

Supports: `\r`, `\n`, `\t`, `\f`, `\a`, `\e`, `\\`, `\0` (octal), `\x1f` (hex), `\u0041` (unicode), `\U00000041` (extended unicode), `\x{1234}` (braced hex), `\cA` (control characters).

---

## TimeUtils — Human-Readable Time Formatting

```java
TimeUtils.formatMillis(90061000)          // "1 day, 1 hour, 1 minute and 1 second"
TimeUtils.abbreviateMillis(90061000)      // "1d, 1hr, 1m and 1s"
TimeUtils.formatNanos(1500000)            // "1 millisecond and 500 microseconds"

// Custom range
TimeUtils.formatMillis(ms, TimeUnit.HOURS, TimeUnit.DAYS)

// Convenience
TimeUtils.daysAndMinutes()                // preset min/max
TimeUtils.hoursAndMinutes()
TimeUtils.hoursAndSeconds()

// Single largest unit
TimeUtils.formatHighest(ms, TimeUnit.DAYS)  // "2 days"
```

---

## Join — String Joining

```java
String result = Join.join(", ", list);
String result = Join.join(" | ", "a", "b", "c");

// With custom name callback
String result = Join.join(", ", File::getName, files);

// Built-in callbacks
Join.FileCallback, Join.MethodCallback, Join.ClassCallback
```

---

## PrintString — Capture PrintStream Output

```java
PrintString out = new PrintString();
out.println("Hello");
String captured = out.toString();          // "Hello\n"
byte[] bytes = out.toByteArray();
int length = out.size();
```

---

## SuperProperties — Enhanced Properties

Extends `java.util.Properties` with:
- **Ordered keys** (LinkedHashMap-backed)
- **Per-property comments** — preserved across load/save
- **Per-property attributes** — key-value metadata on each property
- **Case-insensitive lookup** option

---

## Converter — Type Conversion

Convert strings to Java types using a chain of strategies.

```java
Object value = Converter.convert("123", Integer.class, "portNumber");
Object value = Converter.convert("10kb", Size.class, "maxSize");
Object value = Converter.convert("PRODUCTION", MyEnum.class, "env");
```

**Conversion chain** (first match wins):
1. Registered `PropertyEditor`
2. `Enum.valueOf()` (case-insensitive: exact, uppercase, lowercase)
3. `Constructor(String)`
4. `Constructor(CharSequence)`
5. Public static method taking `String` returning the type (`valueOf`, `of`, `parse`)

Supports collections: `List<T>`, `Set<T>`, `Map<K,V>`, arrays. Supports Java Records (14+).

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

## Reflection Utilities

### Generics

Resolve generic type parameters through inheritance hierarchies:

```java
Type[] types = Generics.getInterfaceTypes(Iterator.class, MyList.class);
Type fieldType = Generics.getType(field);
Type returnType = Generics.getReturnType(method);
```

### Classes

```java
Class<?> cls = Classes.forName("int[]", classLoader);  // handles arrays/primitives
String pkg = Classes.packageName(MyClass.class);
String simple = Classes.simpleName(MyClass.class);
Class<?> boxed = Classes.deprimitivize(int.class);     // Integer.class
List<Class<?>> hierarchy = Classes.ancestors(MyClass.class);
```

### StackTraceElements

```java
StackTraceElement current = StackTraceElements.getCurrentMethod();
StackTraceElement caller = StackTraceElements.getCallingMethod();
Class<?> cls = StackTraceElements.asClass(element);
```

---

## Hash Utilities

### XxHash32 / XxHash64

Fast non-cryptographic hashing (xxHash algorithm):

```java
int hash = new XxHash32().update(bytes).hash();
long hash = new XxHash64().update(bytes).hash();

// With seed
int hash = new XxHash32(seed).update(data).hash();
```

---

## Other Utilities

### Version

```java
Version v = Version.parse("1.2.3");
v.compareTo(Version.parse("1.3.0"));      // -1
String[] sorted = Version.sort(versions);  // semantic sort
```

### Futures

```java
Future<List<String>> combined = Futures.of(future1, future2, future3);
List<String> results = combined.get();     // waits for all
```

### Pipe

```java
Future<Pipe> pipe = Pipe.pipe(inputStream, outputStream);  // background copy
Future<List<Pipe>> pipes = Pipe.pipe(process);             // pipe Process streams
```

### JarLocation

```java
File jar = JarLocation.jarLocation(MyClass.class);  // JAR containing class
```

### Mvn

```java
File artifact = Mvn.mvn("org.example:mylib:1.0:jar");  // local repo lookup
```

### Zips

```java
Zips.unzip(zipFile, destinationDir);
```

### Formats

```java
String dt = Formats.asDateTime(System.currentTimeMillis());  // "2025-03-14 10:30:45"
```

### Bytes

Byte accumulator with automatic unit compaction:

```java
Bytes b = new Bytes();
b.add(1048576);
long mb = b.get();  // in MB
```
