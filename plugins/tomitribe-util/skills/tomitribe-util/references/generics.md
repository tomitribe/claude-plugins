# Generics — Resolve Generic Type Parameters Through Inheritance

**Package:** `org.tomitribe.util.reflect`

Resolves actual type arguments from generic interfaces, superclasses, fields, methods, and parameters — walking full inheritance hierarchies including multi-level type variable forwarding.

## API

```java
// Resolve the FIRST generic type argument of a field (e.g., Collection<URI> -> URI)
// Shorthand for getTypeParameters(field.getType(), field.getGenericType())[0]
Type getType(Field field)

// Resolve the FIRST generic type argument of a method/constructor parameter
// Shorthand for getTypeParameters(parameter.getType(), parameter.getGenericType())[0]
Type getType(Parameter parameter)

// Resolve the FIRST generic type argument of a method return type (e.g., Set<URL> -> URL)
// Shorthand for getTypeParameters(method.getReturnType(), method.getGenericReturnType())[0]
Type getReturnType(Method method)

// Resolve the generic type arguments for a specific interface implemented by a class.
// Returns the resolved Type[] for the interface's type parameters, or null if
// the class does not implement the interface.
Type[] getInterfaceTypes(Class<?> interfaceClass, Class<?> implementingClass)

// Walk the type hierarchy from `type` up to `genericClass`, resolving
// type variables along the way. Returns ALL actual type arguments as Type[], or null.
// Use this instead of getType/getReturnType when you need more than the first type argument.
Type[] getTypeParameters(Class<?> genericClass, Type type)
```

**Important:** `getType(Field)`, `getType(Parameter)`, and `getReturnType(Method)` return only the **first** type argument (`[0]`). When a type has multiple type parameters (e.g., `Map<K,V>`, `Function<T,R>`, `RequestHandler<I,O>`), use `getTypeParameters()` directly to get **all** type arguments.

## Resolving Field, Parameter, and Return Types

Extract the resolved generic type from fields, method parameters, and return types.

```java
// Field: Collection<URI> uris -> URI
Type fieldType = Generics.getType(MyClass.class.getField("uris"));
// fieldType == URI.class

// Method return type: Set<URL> urls() -> URL
Type returnType = Generics.getReturnType(MyClass.class.getMethod("urls"));
// returnType == URL.class

// Method parameter: void set(List<Integer> integers) -> Integer
Parameter param = Reflection.params(MyClass.class.getMethod("set", List.class))
        .iterator().next();
Type paramType = Generics.getType(param);
// paramType == Integer.class

// Constructor parameter: MyClass(Queue<URI> uris) -> URI
Parameter ctorParam = Reflection.params(MyClass.class.getConstructor(Queue.class))
        .iterator().next();
Type ctorParamType = Generics.getType(ctorParam);
// ctorParamType == URI.class
```

## Getting All Type Arguments from Fields, Parameters, and Return Types

`getType()` and `getReturnType()` only return the first type argument. When the generic type
has multiple type parameters, use `getTypeParameters()` to get all of them.

```java
// Constructor parameter:
// public ApiGatewayConduit(RequestHandler<APIGatewayProxyRequestEvent, APIGatewayV2HTTPResponse> handler)
Parameter param = Reflection.params(
        ApiGatewayConduit.class.getConstructor(RequestHandler.class))
        .iterator().next();

// WRONG: getType() only returns the first type argument
Type first = Generics.getType(param);
// first == APIGatewayProxyRequestEvent.class (the second arg is lost)

// RIGHT: getTypeParameters() returns all type arguments
Type[] types = Generics.getTypeParameters(
        RequestHandler.class, param.getGenericType());
// types[0] == APIGatewayProxyRequestEvent.class
// types[1] == APIGatewayV2HTTPResponse.class

// Method parameter — same pattern, use getMethod instead of getConstructor:
// public void handle(RequestHandler<APIGatewayProxyRequestEvent, APIGatewayV2HTTPResponse> handler)
Parameter methodParam = Reflection.params(
        MyClass.class.getMethod("handle", RequestHandler.class))
        .iterator().next();

Type[] methodTypes = Generics.getTypeParameters(
        RequestHandler.class, methodParam.getGenericType());
// methodTypes[0] == APIGatewayProxyRequestEvent.class
// methodTypes[1] == APIGatewayV2HTTPResponse.class

// Fields:
// Map<String, URI> entries
Type[] mapTypes = Generics.getTypeParameters(
        Map.class, MyClass.class.getField("entries").getGenericType());
// mapTypes[0] == String.class, mapTypes[1] == URI.class

// Method return types:
// Map<String, URI> getEntries()
Type[] returnTypes = Generics.getTypeParameters(
        Map.class, MyClass.class.getMethod("getEntries").getGenericReturnType());
// returnTypes[0] == String.class, returnTypes[1] == URI.class
```

## Resolving Interface Type Arguments — Direct Implementation

Given an interface with type parameters, resolve the actual types supplied by an implementing class.

```java
// Single type parameter
class URIConsumer implements Consumer<URI> { ... }

Type[] types = Generics.getInterfaceTypes(Consumer.class, URIConsumer.class);
// types[0] == URI.class

// Multiple type parameters
class MyFunction implements Function<URL, File> { ... }

Type[] types = Generics.getInterfaceTypes(Function.class, MyFunction.class);
// types[0] == URL.class, types[1] == File.class
```

## Resolving Through Inheritance — Parent Specifies Types

When a parent class specifies the type arguments, subclasses inherit the resolved types.

```java
class URIConsumer implements Consumer<URI> { ... }
class SpecializedConsumer extends URIConsumer { }

Type[] types = Generics.getInterfaceTypes(Consumer.class, SpecializedConsumer.class);
// types[0] == URI.class — resolved through parent
```

## Resolving Deferred Type Variables — Subclass Specifies Types

A parent can leave type parameters as variables, letting subclasses supply the concrete types.
Works through multiple levels of inheritance.

```java
// One level of deferral
class AbstractConsumer<T> implements Consumer<T> { ... }
class URIConsumer extends AbstractConsumer<URI> { }

Type[] types = Generics.getInterfaceTypes(Consumer.class, URIConsumer.class);
// types[0] == URI.class

// Multi-level deferral: type variable forwarded through two abstract classes
class AbstractConsumer<T> implements Consumer<T> { ... }
class MiddleConsumer<V> extends AbstractConsumer<V> { }
class ConcreteConsumer extends MiddleConsumer<URI> { }

Type[] types = Generics.getInterfaceTypes(Consumer.class, ConcreteConsumer.class);
// types[0] == URI.class — resolved through two levels
```

## Resolving Through Interface Inheritance

The target interface can be inherited through intermediate interfaces, not just classes.

```java
interface ImprovedConsumer<T> extends Consumer<T> { }

class MyConsumer implements ImprovedConsumer<URI> { ... }

Type[] types = Generics.getInterfaceTypes(Consumer.class, MyConsumer.class);
// types[0] == URI.class — resolved through interface hierarchy

// With deferred type variables through interface chain
class AbstractConsumer<R> implements ImprovedConsumer<R> { ... }
class SpecializedConsumer extends AbstractConsumer<URI> { }

Type[] types = Generics.getInterfaceTypes(Consumer.class, SpecializedConsumer.class);
// types[0] == URI.class
```

## Ignoring Unrelated Generic Interfaces

When a class implements multiple generic interfaces, only the requested interface's
type arguments are returned. Other interfaces are ignored.

```java
class Multi implements Consumer<URI>, Function<URL, File> { ... }

Type[] consumerTypes = Generics.getInterfaceTypes(Consumer.class, Multi.class);
// consumerTypes == [URI.class] — Function types ignored

Type[] functionTypes = Generics.getInterfaceTypes(Function.class, Multi.class);
// functionTypes == [URL.class, File.class] — Consumer types ignored
```

## Mix of Direct and Deferred Type Parameters

Some type parameters can be specified directly while others are deferred to subclasses.

```java
// URIConsumer fixes the return type (File) but defers the input type (I)
class URIConsumer<I> implements Consumer<URI>, Function<I, File> { ... }
class Specialized extends URIConsumer<URL> { }

Type[] types = Generics.getInterfaceTypes(Function.class, Specialized.class);
// types[0] == URL.class — resolved from subclass
// types[1] == File.class — resolved from parent
```

## Parameterized Types as Type Arguments

Type arguments can themselves be parameterized types (e.g., `Consumer<Function<URL, File>>`).
The returned `Type[]` will contain `ParameterizedType` instances that can be further inspected.

```java
class FunctionConsumer implements Consumer<Function<URL, File>> { ... }

Type[] types = Generics.getInterfaceTypes(Consumer.class, FunctionConsumer.class);
// types[0] instanceof ParameterizedType
ParameterizedType funcType = (ParameterizedType) types[0];
// funcType.getRawType() == Function.class
// funcType.getActualTypeArguments() == [URL.class, File.class]
```

This also works with deferred variables inside parameterized type arguments:

```java
class AbstractFunctionConsumer<V> implements Consumer<Function<V, File>> { ... }
class Specialized extends AbstractFunctionConsumer<URL> { }

Type[] types = Generics.getInterfaceTypes(Consumer.class, Specialized.class);
ParameterizedType funcType = (ParameterizedType) types[0];
// funcType.getRawType() == Function.class
// funcType.getActualTypeArguments() == [URL.class, File.class]
// URL was resolved from the subclass type variable V
```

## Interface Not Implemented — Returns null

If the class does not implement the specified interface, `null` is returned (not an empty array).

```java
class URIConsumer implements Consumer<URI> { ... }

Type[] types = Generics.getInterfaceTypes(Function.class, URIConsumer.class);
// types == null — URIConsumer does not implement Function
```
