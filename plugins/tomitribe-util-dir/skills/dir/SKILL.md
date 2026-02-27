# Dir - Strongly Typed Filesystem Manipulation

Java utility for compile-time checked, code-completable file path references using dynamic proxies.
Eliminates string-based `Path` references by modeling directory structures as interfaces.

**Package:** `org.tomitribe.util.paths`
**Location:** `~/work/tomitribe/tomitribe-util`

## Maven Coordinates

```xml
<groupId>org.tomitribe</groupId>
<artifactId>tomitribe-util</artifactId>
```

## Core Concept

Define an interface whose methods mirror a directory structure.  `Dir.of()` returns a dynamic proxy
that resolves method calls to `java.nio.file.Path` references.

```java
// Instead of error-prone strings:
Path srcMainResources = moduleDir.resolve("src/main/resources");
Path srcTestResources = moduleDir.resolve("src/test/resource"); // typo!

// Use compile-time checked interfaces:
Module module = Dir.of(Module.class, moduleDir);
Path srcMainResources = module.src().main().resources();
Path srcTestResources = module.src().test().resources();
```

## Creating a Dir Interface

Methods return `Path` for leaf entries, or another interface for subdirectories:

```java
public interface Project {
    Src src();           // returns another interface (subdirectory)
    Path target();       // returns Path
    @Name("pom.xml")
    Path pomXml();       // @Name for non-Java-identifier filenames
    @Name(".gitignore")
    Path gitignore();    // works for hidden files too
}

public interface Src {
    Section main();
    Section test();
    Section section(String name);  // dynamic subdirectory name
}

public interface Section {
    Path java();
    Path resources();
}
```

## Instantiation

```java
import org.tomitribe.util.paths.Dir;

Path mydir = java.nio.file.Paths.get("/some/path/to/project");
Project project = Dir.of(Project.class, mydir);
```

## Annotations Reference

| Annotation | Target | Purpose |
|------------|--------|---------|
| `@Name("filename")` | Method | Override the filename (default: method name) |
| `@Filter(Predicate.class)` | Method | Filter listings by `Predicate<Path>` (repeatable) |
| `@Walk` | Method | Recursive traversal instead of direct children only |
| `@Walk(maxDepth=N)` | Method | Limit recursion depth |
| `@Walk(minDepth=N)` | Method | Skip results shallower than N levels |
| `@Walk(minDepth=M, maxDepth=N)` | Method | Window into a specific depth range |
| `@Mkdir` | Method | Create directory on access (parent must exist) |
| `@Mkdirs` | Method | Create directory and all parents on access |
| `@Parent` | Method | Navigate to parent directory (1 level up) |
| `@Parent(N)` | Method | Navigate N levels up |

## Return Types

Methods can return:

- **`Path`** -- resolves to a file or directory path
- **Another interface** -- creates a nested Dir proxy for a subdirectory
- **Another interface with `String` arg** -- creates a proxy for a dynamically-named subdirectory
- **`Path[]`** -- lists directory contents as an array
- **`Stream<Path>`** -- lists directory contents as a stream
- **Interface array (`Module[]`)** -- lists contents, each wrapped in a Dir proxy
- **Interface stream (`Stream<Module>`)** -- streams contents, each wrapped in a Dir proxy
- **Custom wrapper class** -- see Custom Wrapper Objects below

## Listing Files

### Unfiltered

```java
public interface Project extends Dir {
    Path[] modules();           // array of all direct children
    Stream<Path> modules();     // stream of all direct children
}
```

### Filtered with `@Filter`

Implement `Predicate<Path>` and reference it with `@Filter`:

```java
public static class HasPomXml implements Predicate<Path> {
    @Override
    public boolean test(final Path path) {
        return java.nio.file.Files.exists(path.resolve("pom.xml"));
    }
}

public interface Project extends Dir {
    @Filter(HasPomXml.class)
    Module[] modules();

    @Filter(HasPomXml.class)
    Stream<Module> modules();
}
```

### Repeatable `@Filter`

Stack multiple `@Filter` annotations; all must pass:

```java
public interface Work extends Dir {
    @Walk
    @Filter(IsJunit.class)
    @Filter(IsTxt.class)
    Stream<Path> junitTxtFiles();
}
```

### Recursive with `@Walk`

```java
public interface Project extends Dir {
    @Walk                          // unlimited depth
    @Filter(HasPomXml.class)
    Stream<Module> allModules();

    @Walk(maxDepth = 3)            // limit depth
    @Filter(HasPomXml.class)
    Stream<Module> nearModules();

    @Walk(minDepth = 2, maxDepth = 2)  // exact depth
    Stream<Path> exactlyTwoDeep();
}
```

`@Walk` works with both `Stream` and array return types.

## `@Mkdir` and `@Mkdirs`

```java
public interface Section {
    @Mkdirs    // creates directory AND all missing parents
    Path java();

    @Mkdir     // creates directory only (parent must exist)
    Path resources();
}
```

Directories are created lazily when the method is invoked:

```java
// src/main/java is created (along with src/ and src/main/) at this point:
Path srcMainJava = project.src().main().java();
```

## `@Parent` for Navigating Up

```java
public interface Module extends Dir {
    @Name("pom.xml") Path pomXml();
    Src src();
}

public interface Src {
    @Parent Module module();         // 1 level up: src/ -> project/
    Section main();
    Section test();
}

public interface Section {
    @Parent(2) Module module();      // 2 levels up: src/main/ -> project/
    Path java();
    Path resources();
}

public interface Java extends Dir {
    @Parent(3) Module module();      // 3 levels up: src/main/java/ -> project/
}
```

## Extending the `Dir` Interface

Interfaces can extend `Dir` to gain built-in methods:

```java
public interface Module extends Dir {
    @Name("pom.xml") Path pomXml();
    Src src();
}
```

**Built-in `Dir` methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `dir()` | `Path` | The path for this directory |
| `get()` | `Path` | Synonym for `dir()` |
| `dir(String name)` | `Dir` | A Dir wrapping a named subdirectory |
| `file(String name)` | `Path` | Path for a named file or subdirectory |
| `parent()` | `Path` | The parent path |
| `mkdir()` | `Path` | Create this directory (parent must exist) |
| `mkdirs()` | `Path` | Create this directory and all parents |
| `delete()` | `void` | Recursively delete this directory |
| `walk()` | `Stream<Path>` | All files and directories recursively |
| `walk(int depth)` | `Stream<Path>` | Walk limited to given depth |
| `files()` | `Stream<Path>` | Only files (no directories) recursively |
| `files(int depth)` | `Stream<Path>` | Files limited to given depth |

## Custom Wrapper Objects

Methods can return custom classes that wrap a `Path`.  The class needs either:
- A **public constructor** taking a single `Path` argument, OR
- A **public static factory method** taking a single `Path` and returning the class type

```java
// Constructor-based
public class Pom {
    private final Path file;
    public Pom(final Path file) { this.file = file; }
    public Path getFile() { return file; }
}

// Factory method-based
public class Archivo {
    private final Path path;
    private Archivo(final Path path) { this.path = path; }
    public static Archivo from(final Path path) { return new Archivo(path); }
}

public interface Module extends Dir {
    @Name("pom.xml") Pom pomXml();               // single wrapper

    @Walk @Filter(IsJava.class)
    Stream<Archivo> javaFiles();                   // stream of wrappers

    @Walk @Filter(IsJava.class)
    Archivo[] javaFileArray();                     // array of wrappers
}
```

## Default Methods

Interfaces support default methods for custom logic:

```java
public interface Repository extends Dir {
    default Group group(final String name) {
        final String path = name.replace(".", "/");
        final Group group = Dir.of(Group.class, dir().resolve(path));
        group.mkdirs();
        return group;
    }
}

Repository repo = Dir.of(Repository.class, someDir);
Group group = repo.group("org.color");  // creates org/color/ directory
```

## `equals`, `hashCode`, `toString`

Dir proxies implement `equals`/`hashCode` based on the underlying `Path`, and `toString` returns the absolute path string.

```java
Dir a = Dir.of(Dir.class, Paths.get("/foo/bar"));
Dir b = Dir.of(Dir.class, Paths.get("/foo/bar"));
a.equals(b);    // true
a.toString();    // "/foo/bar"
```
