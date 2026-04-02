# Encoding/Decoding and Numeric Conversion

## Encoding/Decoding

### Hex

```java
String hex = Hex.toString(bytes);          // "48656c6c6f"
byte[] bytes = Hex.fromString("48656c6c6f");
```

### Base32

```java
String encoded = Base32.encode(bytes);
byte[] decoded = Base32.decode(encoded);
```

### Base58

```java
String encoded = Base58.encode(bytes);     // Bitcoin-style alphabet
byte[] decoded = Base58.decode(encoded);
```

### Base64

```java
byte[] encoded = Base64.encodeBase64(bytes);
byte[] encodedChunked = Base64.encodeBase64Chunked(bytes);  // 76-char lines
byte[] decoded = Base64.decodeBase64(encoded);
```

### Binary

```java
byte[] bytes = Binary.toBytes("01001000");
BitSet bits = Binary.toBitSet("01001000");
String binary = Binary.toString(bytes);
```

---

## Numeric Conversion

### Ints

```java
byte[] bytes = Ints.toBytes(42);           // 4-byte big-endian
int value = Ints.fromBytes(bytes);
String hex = Ints.toHex(42);
int value = Ints.fromHex("2a");
```

### Longs

```java
byte[] bytes = Longs.toBytes(42L);         // 8-byte big-endian
long value = Longs.fromBytes(bytes);
String hex = Longs.toHex(42L);
String b32 = Longs.toBase32(42L);
String b58 = Longs.toBase58(42L);
String b64 = Longs.toBase64(42L);
// And corresponding fromHex, fromBase32, fromBase58, fromBase64
```
