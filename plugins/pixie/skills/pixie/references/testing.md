# Testing

### Plain Java — No Framework Needed

Every Pixie component can be instantiated with `new`:

```java
@Test
public void testPerson() {
    final Address home = new Address("820 Roosevelt Street",
            "River Falls", State.WI, 54022, "USA");
    final Person person = new Person("jane", 37, home);
    assertEquals("jane", person.getName());
}
```

#### Testing Events with Consumer

`@Event Consumer<T>` is just a constructor parameter. Pass a lambda:

```java
@Test
public void testOrderFiresEvent() {
    final List<OrderProcessed> firedEvents = new ArrayList<>();
    final ShoppingCart cart = new ShoppingCart(firedEvents::add);

    cart.order("order-123");

    assertEquals(1, firedEvents.size());
    assertEquals("order-123", firedEvents.get(0).getId());
}
```

#### Testing Observers

Observer methods are regular methods — call them directly:

```java
@Test
public void testEmailReceipt() {
    final EmailReceipt receipt = new EmailReceipt();
    receipt.onOrderProcessed(new OrderProcessed("order-456"));
    assertEquals(1, receipt.getOrdersProcessed().size());
}
```

### System.builder() — Integration Tests

For tests that exercise full Pixie wiring:

```java
@Test
public void testFullSystem() {
    final System system = System.builder()
            .definition(Person.class, "jane")
            .param("age", 37)
            .comp("address", "home")
            .definition(Address.class, "home")
            .param("street", "820 Roosevelt Street")
            .param("city", "River Falls")
            .param("state", "WI")
            .param("zipcode", "54022")
            .build();

    final Person jane = system.get(Person.class);
    assertEquals(37, jane.getAge());
}
```

#### Injecting Test Doubles

Use `add()` to substitute mocks or stubs:

```java
@Test
public void testWithMockProcessor() {
    final List<String> charged = new ArrayList<>();

    final System system = System.builder()
            .add("stripe", (PaymentProcessor) charged::add)
            .definition(ShoppingCart.class, "cart")
            .build();

    system.get(ShoppingCart.class).order("order-101");
    assertEquals(1, charged.size());
}
```
