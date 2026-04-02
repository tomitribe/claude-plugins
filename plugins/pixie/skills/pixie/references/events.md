# Events

### Firing Events with `@Event`

Injects a `Consumer<T>` that dispatches events to all observers in the System:

```java
public class ShoppingCart {
    private final Consumer<OrderProcessed> orderProcessedEvent;

    public ShoppingCart(@Event final Consumer<OrderProcessed> orderProcessedEvent) {
        this.orderProcessedEvent = orderProcessedEvent;
    }

    public void order(final String orderId) {
        orderProcessedEvent.accept(new OrderProcessed(orderId));
    }
}
```

A component can inject multiple event consumers for different types:

```java
public OrderService(@Event final Consumer<OrderPlaced> orderPlaced,
                    @Event final Consumer<OrderShipped> orderShipped) { ... }
```

Events can also be fired directly on the System:

```java
system.fireEvent(new OrderProcessed("order123"));
```

### Observing Events with `@Observes`

Marks a method parameter as an event listener:

```java
public class EmailReceipt {
    public void onOrderProcessed(@Observes final OrderProcessed event) {
        sendEmail(event.getId());
    }
}
```

Multiple observers, multiple event types, multiple observer methods per component — all supported.

#### Polymorphic Observation

Observation is polymorphic — matches any event **assignable** to the parameter type:

```java
// Receives OrderProcessed and any subclass
public void onOrder(@Observes final OrderProcessed event) { ... }

// Receives every event in the system
public void onAny(@Observes final Object event) { ... }
```

#### Most-Specific Matching

When both a supertype and subtype observer exist, only the **most specific** match is called:

```java
public class Listener {
    // Called for Integer events
    public void onInteger(@Observes final Integer event) { ... }

    // Called for Long, Double, etc. — but NOT Integer
    public void onNumber(@Observes final Number event) { ... }
}
```

#### Exception Handling

Observer exceptions do not propagate to the event producer. Instead, Pixie fires an `ObserverFailed` event:

```java
public class ErrorHandler {
    public void onFailure(@Observes final ObserverFailed event) {
        log.error("Observer " + event.getMethod().getName() + " failed",
                  event.getThrowable());
    }
}
```

### BeforeEvent and AfterEvent

Pixie wraps every event dispatch in lifecycle wrappers:

```java
public class SecurityCheck {
    public void beforeOrder(@Observes final BeforeEvent<OrderProcessed> event) {
        // Runs before any @Observes OrderProcessed methods
        validatePermissions(event.getEvent());
    }
}

public class Metrics {
    public void afterOrder(@Observes final AfterEvent<OrderProcessed> event) {
        // Runs after all @Observes OrderProcessed methods
        recordMetric("order.processed");
    }
}
```

Execution order: `BeforeEvent<T>` → `T` observers → `AfterEvent<T>`

Type matching uses the generic argument — `BeforeEvent<Number>` fires before any `Integer`, `Long`, etc.

### Built-in Events

| Event | Fired When |
|-------|-----------|
| `PixieLoad` | After `system.load(properties)` completes. Contains the loaded `Properties`. |
| `PixieClose` | When `system.close()` is called. |
| `ComponentAdded<T>` | A component is added to the System. Contains the type and instance. |
| `ComponentRemoved<T>` | A component is removed from the System. |
| `ObserverAdded` | An observer is registered with the System. |
| `ObserverRemoved` | An observer is unregistered. |
| `BeforeEvent<T>` | Before an event of type `T` is dispatched. |
| `AfterEvent<T>` | After an event of type `T` has been dispatched. |
| `ObserverFailed` | An observer method threw an exception. Contains observer, method, event, and throwable. |
| `ObserverNotFound` | No observers exist for a fired event. |

`System` implements `Closeable`, so it works with try-with-resources:

```java
try (final System system = new System(properties)) {
    // PixieLoad fires after construction
} // PixieClose fires here
```
