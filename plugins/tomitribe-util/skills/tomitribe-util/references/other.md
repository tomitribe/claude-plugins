# Other Utilities

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

---

## Reflection Utilities

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
