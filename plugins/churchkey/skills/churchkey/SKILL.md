# Churchkey - Cryptographic Key Library

Java library for parsing and exporting cryptographic keys across multiple formats.
Format-agnostic: pass key bytes and it auto-detects format, parses, and returns a standardized `Key` object.

**Location:** `~/work/tomitribe/churchkey`

## Maven Coordinates

```xml
<groupId>io.churchkey</groupId>
<artifactId>churchkey</artifactId>
<version>1.23-SNAPSHOT</version>  <!-- dev; latest release: 1.21 -->
```

## Supported Formats

| Format   | Enum                | Notes                                    |
|----------|---------------------|------------------------------------------|
| PEM      | `Key.Format.PEM`    | PKCS1, PKCS8, X.509, OpenSSL EC          |
| JWK      | `Key.Format.JWK`    | RFC 7517, includes JWK Sets              |
| OpenSSH  | `Key.Format.OPENSSH`| ssh-rsa, ssh-dss, ecdsa-sha2-*           |
| SSH2     | `Key.Format.SSH2`   | RFC 4716                                 |

## Supported Algorithms

`Key.Algorithm` enum: `RSA`, `DSA`, `EC`, `OCT`

EC supports 100+ curves (NIST P-256/384/521, secp256k1, Brainpool, binary, etc.)
via `Curve` enum. Resolve by name: `Curve.resolve("P-256")`.

## Key Types

`Key.Type` enum: `PUBLIC`, `PRIVATE`, `SECRET`

## Core API

### Keys.java (Factory - primary entry point)

```java
// Decode - auto-detects format
Key          Keys.decode(String contents)
Key          Keys.decode(byte[] bytes)
Key          Keys.decode(File file)
List<Key>    Keys.decodeSet(String contents)
List<Key>    Keys.decodeSet(byte[] bytes)

// Wrap JCE keys
Key          Keys.of(java.security.Key key)
Key          Keys.of(KeyPair pair)

// Encode
byte[]       Keys.encode(Key key)
byte[]       Keys.encode(Key key, Key.Format format)
byte[]       Keys.encodeSet(List<Key> keys, Key.Format format)
```

### Key.java (Main wrapper)

```java
// Getters
java.security.Key    getKey()
Key.Type             getType()        // PUBLIC, PRIVATE, SECRET
Key.Algorithm        getAlgorithm()   // RSA, DSA, EC, OCT
Key.Format           getFormat()      // PEM, JWK, OPENSSH, SSH2
Key                  getPublicKey()   // Extract public from private

// Attributes (JWK metadata like kid, use, alg)
String               getAttribute(String name)
Map<String,String>   getAttributes()
boolean              hasAttribute(String name)

// Convenience encode methods
byte[]  encode(Key.Format format)
String  toJwk()
String  toJwks()
String  toPem()
String  toOpenSsh()
String  toSsh2()
```

### Key Component Builders

```java
// RSA
Rsa.Public.builder().modulus(n).publicExponent(e).build().toKey()
Rsa.Private.builder().modulus(n).publicExponent(e).privateExponent(d)
    .primeP(p).primeQ(q).primeExponentP(dp).primeExponentQ(dq)
    .crtCoefficient(qi).build().toKey()

// DSA
Dsa.Public.builder().y(y).p(p).q(q).g(g).build().toKey()
Dsa.Private.builder().x(x).y(y).p(p).q(q).g(g).build().toKey()

// EC
Ecdsa.Public.builder().curve(Curve).x(x).y(y).build().toKey()
Ecdsa.Private.builder().curve(Curve).x(x).y(y).d(d).build().toKey()
```

## Usage Examples

```java
// Parse any key format
Key key = Keys.decode(pemString);
key.getType();       // PUBLIC
key.getAlgorithm();  // RSA

// Cast to JCE type
RSAPublicKey rsa = (RSAPublicKey) key.getKey();

// Convert PEM -> JWK
String jwk = Keys.decode(pemBytes).toJwk();

// Extract public key from private
Key pub = Keys.decode(privateKeyPem).getPublicKey();

// Wrap a generated KeyPair
KeyPairGenerator gen = KeyPairGenerator.getInstance("RSA");
Key key = Keys.of(gen.generateKeyPair());
String openssh = key.toOpenSsh();

// JWK Set
List<Key> keys = Keys.decodeSet(jwksJson);
byte[] jwks = Keys.encodeSet(keys, Key.Format.JWK);

// Attributes
key.getAttributes().put("kid", "my-key-id");
key.getAttributes().put("use", "sig");
```

## Exceptions

- `InvalidJwkException` / `InvalidJwksException`
- `InvalidPublicKeySpecException` / `InvalidPrivateKeySpecException`
- `UnsupportedAlgorithmException` / `UnsupportedCurveException`
- `UnsupportedKtyAlgorithmException` / `MissingKtyException`

## Build

- Java 8+ target
- Dependencies shaded (nanojson, tomitribe-util) to avoid conflicts
- Package: `io.churchkey`
