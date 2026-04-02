---
name: jaws
description: "Reference for org.tomitribe.jaws.s3 typed S3 proxy library. TRIGGER when: code imports from org.tomitribe.jaws, uses S3.Dir/S3.File interfaces, or user needs strongly-typed Java proxy interfaces for Amazon S3 bucket operations. DO NOT TRIGGER when: working directly with the AWS SDK S3 client."
---

# JAWS - Java AWS S3 Typed Proxy Library

Strongly-typed, proxy-based Java abstraction for Amazon S3. Define plain Java interfaces that mirror your bucket structure; JAWS uses dynamic proxies to translate method calls into S3 API operations. No manual key construction, no pagination handling, no S3 SDK boilerplate.

**Package:** `org.tomitribe.jaws.s3`

## Maven Coordinates

```xml
<groupId>org.tomitribe</groupId>
<artifactId>jaws-s3</artifactId>
<version>2.1.2-SNAPSHOT</version>
```

Test utilities:

```xml
<groupId>org.tomitribe</groupId>
<artifactId>jaws-s3-test</artifactId>
<version>2.1.2-SNAPSHOT</version>
<scope>test</scope>
```

## Core Concepts

1. Define interfaces extending `S3.Dir` (directories) or `S3.File` (files)
2. Create a typed proxy via `bucket.as(MyInterface.class)` or `s3File.as(MyInterface.class)`
3. Call methods on the proxy — JAWS dispatches to S3 based on return type and annotations

## Base Interfaces

All user interfaces should extend one of these from `org.tomitribe.jaws.s3.S3`:

```java
interface S3 {
    S3File file();       // underlying S3File
    S3File parent();     // parent directory (null at bucket root)
}

interface Dir extends S3 {
    S3File file(String name);                                // get child by name
    Stream<S3File> files();                                  // all objects recursively
    Stream<S3File> list();                                   // immediate children (files + dirs)
    Upload upload(File file);                                // upload file
    Upload upload(File file, TransferListener listener);     // upload with progress
}

interface File extends S3 {
    InputStream getValueAsStream();
    String getValueAsString();
    void setValueAsStream(InputStream is);
    void setValueAsString(String value);
    void setValueAsFile(java.io.File file);
    String getETag();
    long getSize();
    Instant getLastModified();
    ObjectMetadata getObjectMetadata();
}
```

## Method Dispatch Rules

JAWS determines S3 behavior from the method's return type:

| Method Signature | Behavior |
|---|---|
| `T method()` where T is an interface | Proxy for child using method name as key segment |
| `T method(String)` where T is an interface | Proxy for named child, validated by any `@Match`/`@Suffix`/`@Filter` on T |
| `S3File method()` | S3File for child using method name as key |
| `Stream<X>` where X extends `S3.Dir` | Delimiter listing, directories only (commonPrefixes) |
| `Stream<X>` where X extends `S3.File` | Delimiter listing, files only (contents) |
| `Stream<S3File>` | Recursive flat listing of all descendant objects |
| `List<X>`, `Set<X>`, `Collection<X>`, `X[]` | Collection variants of above |
| Default methods | Invoked normally |

## Annotations

All annotations are in `org.tomitribe.jaws.s3`.

### @Name — Override Key Segment

Override the S3 key segment derived from the method name. Use when keys contain characters invalid in Java method names.

```java
public interface Version extends S3.Dir {
    @Name("pom.xml")
    S3File pom();

    @Name("maven-metadata.xml")
    S3File metadata();
}
```

Target: METHOD

### @Parent — Navigate Upward

Navigate up the key hierarchy. Default depth is 1. Throws `NoParentException` if bucket root is reached.

```java
public interface Version extends S3.Dir {
    @Parent
    Artifact artifact();       // one level up

    @Parent(2)
    Group group();             // two levels up
}
```

Target: METHOD

### @Recursive — Recursive Listing

Mark a listing method as recursive (all descendants, not just immediate children).

```java
public interface Repository extends S3.Dir {
    // All descendant objects (single flat ListObjects request)
    @Recursive
    Stream<S3File> allFiles();

    // All descendant directories (tree walk, one request per prefix)
    @Recursive
    Stream<Group> allGroups();
}
```

- `Stream<S3File>` with `@Recursive`: single flat listing (efficient)
- `Stream<S3.Dir>` with `@Recursive`: tree walk (one request per prefix level)

Target: METHOD

### @Prefix — Server-Side Prefix Filter

Applied server-side in the `ListObjects` request. Reduces data transferred from AWS. Also validates single-arg method inputs.

```java
public interface Logs extends S3.Dir {
    @Prefix("error-")
    Stream<S3File> errorLogs();

    @Prefix("2024-")
    Stream<S3File> logs2024();
}
```

Target: METHOD

### @Suffix — Client-Side Suffix Filter

Client-side filtering by file suffix. Multiple values are OR'd. Repeatable. Use `exclude=true` to invert.

```java
public interface Assets extends S3.Dir {
    @Suffix(".jar")
    Stream<S3File> jars();

    @Suffix({".jpg", ".png", ".gif"})
    Stream<S3File> images();

    // Include .jar but exclude -sources.jar and -javadoc.jar
    @Suffix(".jar")
    @Suffix(value = {"-sources.jar", "-javadoc.jar"}, exclude = true)
    Stream<S3File> binaryJars();
}
```

Target: METHOD, TYPE

### @Match — Client-Side Regex Filter

Client-side regex filtering. Uses full match (not find). Repeatable. Use `exclude=true` to invert.

```java
public interface Reports extends S3.Dir {
    @Match("daily-\\d{4}-\\d{2}-\\d{2}\\.csv")
    Stream<S3File> dailyReports();

    @Match(value = ".*\\.tmp", exclude = true)
    Stream<S3File> permanentFiles();
}
```

Target: METHOD, TYPE

### @Filter — Custom Predicate Filter

Arbitrary client-side filtering via a `Predicate<S3File>`. The predicate class must have a no-arg constructor. Repeatable; multiple filters are AND'd.

```java
public interface Artifacts extends S3.Dir {
    @Filter(IsSnapshot.class)
    Stream<S3File> snapshots();
}

public class IsSnapshot implements Predicate<S3File> {
    @Override
    public boolean test(final S3File file) {
        return file.getName().contains("SNAPSHOT");
    }
}
```

Target: METHOD, TYPE

### @Delimiter — Override ListObjects Delimiter

Override the default `/` delimiter. Useful for alternative key hierarchies.

```java
public interface DateIndex extends S3.Dir {
    @Delimiter("-")
    Stream<S3File> segments();
}
```

Target: METHOD

### @Marker — Set Listing Start Position

Set the ListObjects starting position. Keys before the marker are skipped. Rarely needed as JAWS handles pagination automatically.

Target: METHOD

### Filter Evaluation Order

Filters apply in this order (cheapest first):

1. **@Prefix** — server-side (never fetches non-matching keys)
2. **@Suffix includes** — client-side string comparison
3. **@Suffix excludes**
4. **@Match includes** — client-side compiled regex
5. **@Match excludes**
6. **@Filter** — arbitrary predicate (runs last)

### Input Validation

Filter annotations on a return type or method also validate single-argument method inputs:

```java
public interface Dir extends S3.Dir {
    // @Suffix on JsonFile's type validates input
    JsonFile file(String name);  // throws IllegalArgumentException if name doesn't end with .json
}

@Suffix(".json")
public interface JsonFile extends S3.File {}
```

## S3Client API

Entry point for all S3 interaction. Wraps `S3AsyncClient`.

```java
// Create
S3Client s3 = new S3Client(S3AsyncClient.builder().build());

// Bucket operations
S3Bucket    createBucket(String name)        // create new bucket
S3Bucket    getBucket(String name)           // get existing (throws NoSuchBucketException)
Stream<S3Bucket>  buckets()                  // list all accessible buckets
```

## S3Bucket API

Represents a single S3 bucket.

```java
// Typed proxy creation
<T> T       as(Class<T> type)               // create typed proxy at bucket root

// Navigation
S3File      root()                           // S3File for bucket root
S3File      getFile(String key)              // S3File for specific key (fetches metadata)

// Content operations (fluent)
S3Bucket    put(String key, String content)  // upload string content
S3Bucket    put(String key, File file)       // upload file
S3Bucket    put(String key, InputStream is, long length)  // upload stream

// Listing
Stream<S3File>  objects()                    // list all objects

// Transfer operations
Upload          upload(String key, File file)
FileDownload    download(String key, File destination)

// Low-level
void        putObject(String key, String content)
String      getObjectAsString(String key)
ResponseInputStream<GetObjectResponse> getObject(String key)
```

## S3File API

Represents a single S3 object or prefix.

```java
// Identity
String      getName()                        // final path segment
String      getAbsoluteName()                // full S3 key

// Content read
String      getValueAsString()
InputStream getValueAsStream()

// Content write
void        setValueAsString(String value)
void        setValueAsStream(InputStream is, long length)
void        setValueAsFile(File file)

// Metadata
String      getETag()
long        getSize()
Instant     getLastModified()
ObjectMetadata getObjectMetadata()
boolean     exists()

// Navigation
S3File      getFile(String childName)        // get child
S3File      getParentFile()                  // get parent (null at root)

// Listing
Stream<S3File>  list()                       // immediate children
Stream<S3File>  files()                      // all descendant objects
Stream<S3File>  walk()                       // depth-limited walk
Stream<S3File>  walk(int maxDepth)           // walk with depth limit

// Proxy creation
<T> T       as(Class<T> type)               // create typed proxy at this location

// Transfers
Upload      upload(File file)
Upload      upload(File file, TransferListener listener)
FileDownload download(File destination)
```

## Usage Examples

### Define a Repository Interface

```java
public interface Repository extends S3.Dir {
    Stream<Group> groups();
    Group group(String name);
}

public interface Group extends S3.Dir {
    Stream<Artifact> artifacts();
    Artifact artifact(String name);
}

public interface Artifact extends S3.Dir {
    Stream<Version> versions();
    Version version(String name);
}

public interface Version extends S3.Dir {
    @Suffix(".jar")
    Stream<S3File> jars();

    @Name("pom.xml")
    S3File pom();

    @Parent
    Artifact artifact();
}
```

### Navigate and Query

```java
S3Client s3 = new S3Client(S3AsyncClient.builder().build());
Repository repo = s3.getBucket("my-repo").as(Repository.class);

// Direct navigation
Version v = repo.group("org.apache").artifact("maven-core").version("3.9.6");
String pom = v.pom().getValueAsString();

// Listing
repo.groups().forEach(group -> {
    group.artifacts().forEach(artifact -> {
        artifact.versions().forEach(version -> {
            version.jars().forEach(jar -> {
                System.out.println(jar.getName() + ": " + jar.getSize());
            });
        });
    });
});

// Navigate upward
Artifact parent = v.artifact();
```

### Upload and Download

```java
// Fluent bucket population
S3Bucket bucket = s3.createBucket("assets")
    .put("css/main.css", cssContent)
    .put("js/app.js", jsContent)
    .put("index.html", htmlContent);

// Upload via S3.Dir
Photos photos = bucket.as(Photos.class);
Upload upload = photos.upload(new File("/path/to/photo.jpg"));

// Upload with progress tracking
Upload upload = photos.upload(new File("/path/to/large-file.mp4"),
    new TransferListener() {
        @Override
        public void bytesTransferred(final Context.BytesTransferred context) {
            System.out.println("Transferred: " +
                context.progressSnapshot().transferredBytes());
        }
    });

// Download
FileDownload download = bucket.download("path/to/file.txt",
    new File("/local/file.txt"));
download.completionFuture().join();
```

### Filtering Patterns

```java
public interface BuildArtifacts extends S3.Dir {
    // Only .jar files, excluding sources and javadoc
    @Suffix(".jar")
    @Suffix(value = {"-sources.jar", "-javadoc.jar"}, exclude = true)
    Stream<S3File> binaries();

    // Regex match for dated reports
    @Match("report-\\d{4}-\\d{2}-\\d{2}\\.csv")
    Stream<S3File> dailyReports();

    // Server-side prefix + client-side suffix
    @Prefix("release-")
    @Suffix(".zip")
    Stream<S3File> releaseArchives();

    // Custom predicate
    @Filter(LargerThan1MB.class)
    Stream<S3File> largeFiles();
}

public class LargerThan1MB implements Predicate<S3File> {
    @Override
    public boolean test(final S3File file) {
        return file.getSize() > 1_048_576;
    }
}
```

## Testing with MockS3

JAWS provides an in-memory S3 backend for testing using S3Proxy.

### JUnit 5

```java
import org.tomitribe.jaws.s3.MockS3Extension;

class MyTest {
    @RegisterExtension
    private final MockS3Extension mockS3 = new MockS3Extension();

    @Test
    void testUploadAndRead() {
        final S3Client s3 = new S3Client(mockS3.getS3Client());
        final S3Bucket bucket = s3.createBucket("test")
            .put("greeting.txt", "hello world");

        final Repository repo = bucket.as(Repository.class);
        assertEquals("hello world", repo.file("greeting.txt").getValueAsString());
    }
}
```

### JUnit 4

```java
import org.tomitribe.jaws.s3.MockS3Rule;

public class MyTest {
    @Rule
    public final MockS3Rule mockS3 = new MockS3Rule();

    @Test
    public void test() {
        S3Client s3 = new S3Client(mockS3.getS3Client());
        // ...
    }
}
```

### S3Asserts — Test Assertions

```java
S3Asserts.of(mockS3.getS3Client(), "test-bucket")
    .snapshot()
    .assertContent("file.txt", "expected content")
    .assertExists("path/to/key")
    .assertNotExists("missing.txt");
```

## Exceptions

| Exception | When |
|---|---|
| `NoSuchBucketException` | `getBucket()` for a bucket that doesn't exist |
| `NoSuchS3ObjectException` | Key not found (when method declares `throws FileNotFoundException`) |
| `NoParentException` | `@Parent` navigation reached bucket root |
