---
description: "Reference for org.tomitribe.archie streaming archive transformation library. TRIGGER when: code imports from org.tomitribe.archie, or user needs to transform ZIP/JAR/TAR.GZ archives on-the-fly (inject entries, replace content, skip entries, enhance bytecode while streaming). DO NOT TRIGGER when: working with standard java.util.zip or unrelated archive libraries."
---

# Archie - Streaming Archive Transformation Library

Java library for stream-based manipulation of archive files (ZIP, JAR, TAR.GZ). Apply transformations on-the-fly without extracting to disk: inject entries, replace content, prepend text, skip entries, and enhance bytecode -- all while streaming.

**Package:** `org.tomitribe.archie`

## Maven Coordinates

```xml
<groupId>org.tomitribe</groupId>
<artifactId>archie</artifactId>
<version>1.1-SNAPSHOT</version>
```

## Core Concept

Build a `Transformations` object with rules, then apply it to an archive via a format-specific transformer. Entries stream through one at a time -- no disk extraction, no full archive in memory.

```java
Transformations transformations = Transformations.builder()
    .before(InsertEntry.builder()
        .name("README.txt")
        .content("Hello, World!")
        .build())
    .build();

new JarTransformation(transformations)
    .transform(new File("input.jar"), new File("output.jar"));
```

## Transformations Builder

Central configuration for all transformation rules. Built via `Transformations.builder()`.

### Content Transformation

Transform entry contents using `Function<byte[], byte[]>`:

```java
Transformations.builder()
    // Replace content of specific entries
    .add(name -> name.equals("config.xml"),
         bytes -> newContent.getBytes())

    // Enhance class files (bytecode manipulation)
    .enhance("org/example/MyClass.class", enhancerFunction)

    // Enhance by predicate
    .enhance(name -> name.endsWith(".class"), enhancerFunction)

    // Prepend text to matching entries
    .prepend(name -> name.equals("META-INF/LICENSE"),
        "Copyright Acme Corporation. 2025\n\n")

    .build();
```

### Entry Injection

Insert new entries before or after archive processing:

```java
Transformations.builder()
    // Insert at start of archive
    .before(InsertEntry.builder()
        .name("META-INF/NOTICE")
        .content("Added by build pipeline")
        .build())

    // Insert at end of archive
    .after(InsertEntry.builder()
        .name("build-info.txt")
        .file(new File("build-info.txt"))
        .build())

    // Inline all entries from another JAR (fat JAR)
    .after(new InlineJar(new File("library.jar")))

    // Raw Consumer<ArchiveOutputStream> callback
    .before(archiveOut -> {
        final byte[] bytes = "content".getBytes();
        final JarArchiveEntry entry = new JarArchiveEntry("added.txt");
        entry.setSize(bytes.length);
        archiveOut.putArchiveEntry(entry);
        archiveOut.write(bytes);
        archiveOut.closeArchiveEntry();
    })

    .build();
```

### Entry-Level Callbacks

Execute logic before or after specific entries:

```java
Transformations.builder()
    .beforeEntry(name -> name.endsWith("Red.class"), out -> {
        out.writeEntry("BeforeRed.txt", "Pre-content");
    })
    .afterEntry(name -> name.endsWith("Red.class"), out -> {
        out.writeEntry("AfterRed.txt", "Post-content");
    })
    .build();
```

### Skipping Entries

Remove entries from the output:

```java
Transformations.builder()
    .skip(entry -> entry.equals("unwanted.txt"))
    .skip(entry -> entry.endsWith(".bak"))
    .build();
```

### Skip Transformation (Signed JARs)

Prevent content transformation on signed JARs or specific entries:

```java
Transformations.builder()
    .skipTransformation(name -> name.startsWith("META-INF/"))
    .build();
```

Archie automatically detects signed JARs (manifest with `-Digest` attributes) and skips their transformation.

## Callback Execution Order

1. `beforeArchive()` -- executed first
2. For each entry:
   - `beforeEntry(name)` if predicate matches
   - Content transformation via `enhance()` / `prepend()` / `add()`
   - Entry written to output
   - `afterEntry(name)` if predicate matches
3. `afterArchive()` -- executed last

## Format-Specific Transformers

Each implements the `Transformer` interface and has a fluent builder.

### JarTransformation

For JAR, WAR, EAR, RAR files. Preserves compression method, timestamps, Unix mode, CRC32.

```java
JarTransformation.builder()
    .enhance("org/example/MyClass.class", enhancerFunction)
    .skip(entry -> entry.equals("old-file.txt"))
    .before(InsertEntry.builder().name("added.txt").content("hello").build())
    .build()
    .transform(inputFile, outputFile);
```

### ZipTransformation

For ZIP files. Same builder pattern.

```java
ZipTransformation.builder()
    .prepend(name -> name.equals("README"), "Header\n\n")
    .build()
    .transform(inputStream, outputStream);
```

### TarGzTransformation

For TAR.GZ files. Handles symlinks, hard links, and long filenames (POSIX mode).

```java
TarGzTransformation.builder()
    .before(InsertEntry.builder().name("notice.txt").content("Built by CI").build())
    .build()
    .transform(inputFile, outputFile);
```

### PassThroughTransformation

Copies input to output unchanged. Used as fallback for unsupported formats.

### Auto-Detection

`Transformations.transformer(File)` selects the right transformer by extension:

| Extension | Transformer |
|---|---|
| `.jar`, `.war`, `.ear`, `.rar` | `JarTransformation` |
| `.zip` | `ZipTransformation` |
| `.tar.gz` | `TarGzTransformation` |
| `.pdf` | `PassThroughTransformation` |

```java
transformations.transformer(archiveFile).transform(archiveFile, outputFile);
```

## Transformer Interface

```java
public interface Transformer {
    void transform(InputStream in, OutputStream out) throws IOException;
    default void transform(File src, File dest) throws IOException;
}
```

## InsertEntry

Inserts a new entry into an archive. Detects archive type automatically.

```java
InsertEntry.builder()
    .name("path/in/archive.txt")
    .content("string content")     // or
    .file(new File("local.txt"))   // or
    .bytes(() -> byteArray)        // lazy Supplier<byte[]>
    .build();
```

## ReplaceFileContent

Replaces entry content with a new string:

```java
ReplaceFileContent.builder()
    .content("new content")
    .build();
// Returns Function<byte[], byte[]>
```

## InlineJar

Extracts entries from a source JAR and inlines them into the output archive. Preserves all entry metadata.

```java
new InlineJar(new File("library.jar"))
// Use as Consumer<ArchiveOutputStream> in .after() or .before()
```

## Binary — Digest File Management

File wrapper that manages associated digest files (`.md5`, `.sha1`, `.sha256`).

```java
Binary binary = new Binary("application.jar");

// Write with automatic digest generation
try (Binary.BinaryOutputStream out = binary.write()) {
    out.write(fileBytes);
}
// Creates application.jar.md5, application.jar.sha1, application.jar.sha256

// Read digests
String md5 = binary.getMd5();
String sha1 = binary.getSha1();
String sha256 = binary.getSha256();

// Verify against stored digests
binary.verify();                    // throws on mismatch
binary.verify(System.out);          // logs results, returns boolean

// Generate digests for existing file
binary.generate();
binary.generate(true);              // overwrite existing digest files
```

## Digest Enum

```java
Digest.MD5.digest(file)             // hex digest of file
Digest.SHA1.digest(file)
Digest.SHA256.digest(file)

// Wrap streams for transparent digest calculation
DigestsOutputStream dos = Digest.SHA256.digest(outputStream);
dos.write(data);
String hex = dos.hex();

DigestsInputStream dis = Digest.MD5.digest(inputStream);
// read all data...
String hex = dis.hex();
String base64 = dis.base64();
```

## Utility Classes

### Zips

```java
Zips.unzip(zipFile, destinationDir);
String listing = Zips.list(zipFile);    // tree listing with hashes
```

### TarGzs

```java
TarGzs.untargz(tarGzFile, destinationDir);
String listing = TarGzs.list(tarGzFile);
```

Both support recursive listing of nested archives and stream-based extraction with file filters.
