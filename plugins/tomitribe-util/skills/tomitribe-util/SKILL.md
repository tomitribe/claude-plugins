---
name: tomitribe-util
description: "Reference for org.tomitribe.util Java utility library. TRIGGER when: code imports from org.tomitribe.util or sub-packages, or user mentions tomitribe-util, Duration, Size, IO, Files, Archive, StringTemplate, Converter, ObjectMap, Generics, Hex, Base32, Base64, XxHash, Join, Options, or related utility classes. DO NOT TRIGGER when: working with unrelated utility libraries."
---

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

## Encoding/Decoding

Hex, Base32, Base58, Base64, Binary encoding/decoding plus Ints/Longs numeric conversion utilities.
For full API details, read `references/encoding.md`.

## Generics — Generic Type Resolution

Resolve actual type arguments from generic interfaces, superclasses, fields, methods, and parameters — walking full inheritance hierarchies.
**Package:** `org.tomitribe.util.reflect`
For full API and examples, read `references/generics.md`.

## Collections, Options, ObjectMap, and SuperProperties

AbstractIterator, FilteredIterator, CompositeIterator, Suppliers for iterator/stream conversion. Options for strongly-typed properties with enum support. ObjectMap for Map views of JavaBean/Record properties. SuperProperties for ordered, commented properties.
For full API details, read `references/collections.md`.

## Escapes, TimeUtils, Hashing, Reflection, and Other Utilities

Escapes string unescaping, TimeUtils human-readable time formatting, XxHash32/XxHash64 non-cryptographic hashing, Classes/StackTraceElements reflection helpers, plus Version, Futures, Pipe, JarLocation, Mvn, Zips, Formats, and Bytes.
For full API details, read `references/other.md`.
