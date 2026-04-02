---
name: swizzle
description: "Reference for org.tomitribe.swizzle.stream stream manipulation and lexer library. TRIGGER when: code imports from org.tomitribe.swizzle, or user needs to find/replace/transform data in InputStreams using fixed string tokens, stream filters, or stream lexing. DO NOT TRIGGER when: working with regex-based stream processing or unrelated stream libraries."
---

# Swizzle - Stream Manipulation Library

Java library for finding, manipulating, and transforming data in streams using fixed string tokens (no regex). Provides stream filters for on-the-fly transformation and a stream lexer for token extraction. Memory-efficient with fixed-size buffers.

**Package:** `org.tomitribe.swizzle.stream`

## Maven Coordinates

```xml
<groupId>org.tomitribe</groupId>
<artifactId>swizzle</artifactId>
<version>1.4-SNAPSHOT</version>
```

## Core Design

- **Fixed string tokens only** -- no regex, keeping buffers fixed-size and memory efficient
- **Decorator pattern** -- chain multiple filters on a single InputStream
- **Streaming** -- processes data byte-by-byte, suitable for arbitrarily large streams

## StreamBuilder — Fluent API

The simplest way to use Swizzle. Chain operations and get a transformed stream.

```java
InputStream result = StreamBuilder.of("Hello WORLD, goodbye WORLD")
    .replace("WORLD", "Earth")
    .get();

String output = StreamUtils.streamToString(result);
// "Hello Earth, goodbye Earth"
```

### Factory Methods

```java
StreamBuilder.of(InputStream in)
StreamBuilder.of(File file)
StreamBuilder.of(byte[] bytes)
StreamBuilder.of(String contents)
StreamBuilder.of(String contents, Charset charset)
```

### Operations

```java
// Include only content between tokens
.include(String begin, String end, boolean caseSensitive, boolean keepDelimiters)

// Exclude content between tokens
.exclude(String begin, String end, boolean caseSensitive, boolean keepDelimiters)

// Delete exact token
.delete(String token)

// Delete token and everything between begin/end (inclusive)
.delete(String begin, String end)

// Delete only content between begin/end (keep delimiters)
.deleteBetween(String begin, String end)

// Replace exact token
.replace(String token, String with)
.replace(String token, StringHandler handler)

// Replace begin/end and everything between (inclusive)
.replace(String begin, String end, String with)
.replace(String begin, String end, StringHandler handler)

// Replace only content between begin/end (keep delimiters)
.replaceBetween(String begin, String end, String with)
.replaceBetween(String begin, String end, StringHandler handler)

// Watch for tokens (observe without consuming)
.watch(String token, Consumer<String> consumer)
.watch(String begin, String end, Consumer<String> consumer)
.watch(OutputStream observer)
```

### Terminal Operations

```java
InputStream get()                     // get transformed stream
void to(OutputStream out)             // write to output stream
void run()                            // consume and discard (for side effects)
```

## Stream Filters

All filters extend `FilteredInputStream`. Chain by wrapping one inside another.

### IncludeFilterInputStream

Include only data between begin and end tokens:

```java
InputStream in = new IncludeFilterInputStream(input, "<BODY", "</BODY>");
// Only data between <BODY and </BODY> passes through
```

Options: `caseSensitive` (default true), `keepDelimiters` (default true).

### ExcludeFilterInputStream

Remove data between begin and end tokens:

```java
InputStream in = new ExcludeFilterInputStream(input, "<!--", "-->");
// HTML comments are removed
```

### Chaining Filters

```java
InputStream in = new BufferedInputStream(url.openStream());
in = new IncludeFilterInputStream(in, "<BODY", "</BODY>");
in = new ExcludeFilterInputStream(in, "<!--", "-->");
in = new ExcludeFilterInputStream(in, "<SCRIPT", "</SCRIPT>");
```

## Token Replacement

### ReplaceStringInputStream — Simple A to B

```java
InputStream in = new ReplaceStringInputStream(input, "RED", "YELLOW");
```

Case-insensitive variant:

```java
InputStream in = new ReplaceStringInputStream(input, false, "red", "YELLOW");
```

### ReplaceStringsInputStream — Multiple Replacements

```java
Map<String, String> replacements = new HashMap<>();
replacements.put("RED", "pear");
replacements.put("GREEN", "grape");
replacements.put("BLUE", "banana");

InputStream in = new ReplaceStringsInputStream(input, replacements);
```

### ReplaceVariablesInputStream — Template Variables

```java
Map<String, String> vars = new HashMap<>();
vars.put("name", "Alice");
vars.put("role", "admin");

InputStream in = new ReplaceVariablesInputStream(input, "{", "}", vars);
// "Hello {name}, you are {role}" -> "Hello Alice, you are admin"
```

### DelimitedTokenReplacementInputStream — Custom Logic

Replace content between delimiters using a handler:

```java
InputStream in = new DelimitedTokenReplacementInputStream(input, "${", "}",
    new StringTokenHandler() {
        public String handleToken(String token) {
            return System.getProperty(token, "${" + token + "}");
        }
    });
```

### FixedTokenReplacementInputStream — Handler for Fixed Token

```java
InputStream in = new FixedTokenReplacementInputStream(input, "TODAY",
    token -> new ByteArrayInputStream(LocalDate.now().toString().getBytes()));
```

## Token Handlers

### StreamTokenHandler (Core Interface)

```java
public interface StreamTokenHandler {
    InputStream processToken(String token) throws IOException;
}
```

Returns an InputStream -- can be anything from a simple string to a 10GB file.

### StringTokenHandler (Convenience Base)

```java
public abstract class StringTokenHandler implements StreamTokenHandler {
    public abstract String handleToken(String token) throws IOException;
}
```

### StringHandler (Functional Interface)

```java
StreamBuilder.of(input)
    .replace("${", "}", (StringHandler) token -> System.getProperty(token, ""))
    .get();
```

### MappedTokenHandler

```java
Map<String, String> map = new HashMap<>();
map.put("color", "blue");
map.put("size", "large");

new MappedTokenHandler(map);  // returns mapped value or original token
```

## Token Watching (Observation)

Watch for tokens without consuming them from the stream:

### FixedTokenWatchInputStream

```java
InputStream in = new FixedTokenWatchInputStream(input, "ERROR",
    token -> System.err.println("Found: " + token));
// Stream passes through unchanged; callback fires on each match
```

### DelimitedTokenWatchInputStream

```java
InputStream in = new DelimitedTokenWatchInputStream(input, "<error>", "</error>",
    token -> log.warn("Error found: " + token));
```

## StreamLexer — Token Extraction

Higher-level API for reading specific tokens from streams.

```java
StreamLexer lexer = new StreamLexer(inputStream);
```

### Reading Tokens

```java
// Read content between begin and end tokens
String value = lexer.readToken("<title>", "</title>");

// Read exact token (seek to it and consume)
String token = lexer.readToken("Expected Text");
```

### Seek and Peek

```java
// Seek: advance to token position
String found = lexer.seek("<body>", "</body>");

// Peek: look ahead without advancing
String preview = lexer.peek("<title>", "</title>");
```

### Mark/Unmark — Scoped Reading

Limit reading scope to a section of the stream:

```java
// Mark scope to <project>...</project>
lexer.seekAndMark("<project>", "</project>");

// Nested mark for <dependencies>...</dependencies>
lexer.seekAndMark("<dependencies>", "</dependencies>");

// Read within scope
String groupId = lexer.readToken("<groupId>", "</groupId>");
String artifactId = lexer.readToken("<artifactId>", "</artifactId>");

// Exit scopes
lexer.readAndUnmark();  // exit </dependencies>
lexer.readAndUnmark();  // exit </project>
```

### StreamLexer API

```java
String readToken(String begin, String end)
String readToken(String string)
String seek(String begin, String end)
String seek(String string)
String peek(String begin, String end)
String peek(String string)

StreamLexer mark()
StreamLexer mark(String limit)
void unmark()

boolean seekAndMark(String begin, String end)
boolean readAndMark(String begin, String end)
boolean seekAndUnmark()
boolean readAndUnmark()
```

## StringTemplate

Simple template engine:

```java
StringTemplate template = new StringTemplate("{dir}/{name}.{ext}");

Map<String, String> context = new HashMap<>();
context.put("dir", "foo");
context.put("name", "bar");
context.put("ext", "txt");

String result = template.apply(context);
// "foo/bar.txt"
```

## ResolveUrlInputStream

Resolve relative URLs to absolute:

```java
URL baseUrl = new URL("http://example.com/docs/index.html");
InputStream in = new ResolveUrlInputStream(input, "<A HREF=\"", "\"", baseUrl);
// Converts relative href values to absolute URLs
```

## Utility Methods

```java
StreamUtils.streamToString(InputStream in)    // read entire stream to String
StreamUtils.stringToStream(String original)   // wrap String as InputStream
```

## Key Conventions

- **Case sensitivity**: Most classes accept a `boolean caseSensitive` parameter (default `true`)
- **Delimiter handling**: `keepDelimiters` controls whether begin/end tokens appear in output
- **Null handling**: `StringTokenHandler` returns `"null"` if handler returns null; `StringHandler` returns empty string
- **Stateful streams**: Streams are consumed sequentially and cannot be rewound (except with explicit mark/reset)
- **No regex**: All token matching uses fixed strings for predictable performance
