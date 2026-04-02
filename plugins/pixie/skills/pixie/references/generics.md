# Generic Type Narrowing and Filtering

## Generic Type Narrowing (v2.12)

When a `@Component` parameter has generic type arguments, Pixie narrows matching to only components whose resolved generics are compatible. Raw type parameters (no generics) match any implementation for backwards compatibility.

```java
public interface RequestHandler<I, O> {
    O handle(I input);
}

public class ApiGateway {
    public ApiGateway(@Param("handler") @Component
                      final RequestHandler<APIGatewayProxyRequestEvent,
                                           APIGatewayV2HTTPResponse> handler) {
        // Only RequestHandler implementations with matching type
        // arguments will be injected
    }
}
```

## Wildcards

Wildcards follow standard Java assignability rules:

```java
// Matches any RequestHandler whose first type argument extends Number
@Component RequestHandler<? extends Number, ?> handler

// Matches any RequestHandler whose first type argument is a supertype of Integer
@Component RequestHandler<? super Integer, ?> handler

// Matches any RequestHandler regardless of type arguments
@Component RequestHandler<?, ?> handler
```

Nested parameterized bounds such as `? extends Comparable<String>` are supported.

## Mixed Generic Resolution

Type arguments can come from multiple sources and are correctly stitched together — some from the producer declaration, others from the class hierarchy. For example, a factory returning `BooleanHandler<String>` where `BooleanHandler<I> implements RequestHandler<I, Boolean>` correctly resolves to `RequestHandler<String, Boolean>`.

## Generic Filtering on Collections

When the collection element type has generic type arguments, only matching components are collected:

```java
public class CountHandler implements RequestHandler<String, Integer> { ... }
public class LengthHandler implements RequestHandler<String, Integer> { ... }
public class ValidHandler implements RequestHandler<String, Boolean> { ... }
public class FetchHandler implements RequestHandler<URI, String> { ... }

public class Pipeline {
    public Pipeline(@Param("handlers") @Component
                    final List<RequestHandler<String, Integer>> handlers) {
        // handlers contains CountHandler and LengthHandler only
        // ValidHandler and FetchHandler are excluded
    }
}
```

Raw collection types (`List<RequestHandler>`) collect all implementations. Wildcards work too:

```java
// Collects any RequestHandler whose input type extends Number
@Param("handlers") @Component List<RequestHandler<? extends Number, ?>> handlers
```
