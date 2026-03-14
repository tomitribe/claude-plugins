# HTTP Signatures Java

Java implementation of HTTP Signature authentication (RFC draft - Signing HTTP Messages). Sign and verify HTTP messages using HMAC, RSA, ECDSA, or DSA algorithms. Zero runtime dependencies.

**Package:** `org.tomitribe.auth.signatures`

## Maven Coordinates

```xml
<groupId>org.tomitribe</groupId>
<artifactId>httpSignatures</artifactId>
<version>1.9-SNAPSHOT</version>
```

## Quick Start — Signing

```java
// 1. Define signature template
Signature signature = new Signature(
    "my-key-id",                    // keyId
    "hs2019",                       // signingAlgorithm
    "hmac-sha256",                  // algorithm
    null,                           // parameterSpec
    Arrays.asList("(request-target)", "host", "date", "content-length")
);

// 2. Create key
Key key = new SecretKeySpec("secret".getBytes(), "HmacSHA256");

// 3. Create reusable, thread-safe signer
Signer signer = new Signer(key, signature);

// 4. Sign request
Map<String, String> headers = new HashMap<>();
headers.put("Host", "example.org");
headers.put("Date", "Tue, 07 Jun 2014 20:51:35 GMT");
headers.put("Content-Length", "18");

Signature signed = signer.sign("POST", "/api/endpoint", headers);

// 5. Set Authorization header
request.setHeader("Authorization", signed.toString());
// "Signature keyId=\"my-key-id\",algorithm=\"hs2019\",..."
```

## Quick Start — Verification

```java
// 1. Parse Authorization header
String authHeader = request.getHeader("Authorization");
Signature signature = Signature.fromString(authHeader, Algorithm.HMAC_SHA256);

// 2. Get key for keyId
Key key = lookupKey(signature.getKeyId());

// 3. Verify
Verifier verifier = new Verifier(key, signature);
boolean valid = verifier.verify("POST", "/api/endpoint", headers);
```

## Signature

Represents an HTTP signature -- either a template (for signing) or a complete signature (for verification).

### Constructors

```java
// Template for signing
new Signature(keyId, signingAlgorithm, algorithm, parameterSpec, headers)

// Complete signature for verification
new Signature(keyId, signingAlgorithm, algorithm, parameterSpec, signature, headers)

// With time fields
new Signature(keyId, signingAlgorithm, algorithm, parameterSpec, signature, headers,
              maxSignatureValidityDuration, signatureCreatedTime, signatureExpiresTime)
```

### Parsing

```java
// Parse from Authorization header value
Signature sig = Signature.fromString("Signature keyId=\"...\",algorithm=\"...\",...");
Signature sig = Signature.fromString(authHeader, Algorithm.HMAC_SHA256);
```

### Formatting

```java
sig.toString()         // "Signature keyId=\"...\",algorithm=\"...\",..."
sig.toParamString()    // parameters without "Signature " prefix
```

### Time Validation

```java
sig.verifySignatureValidityDates()   // throws if expired or not yet valid
sig.getSignatureCreation()           // Date
sig.getSignatureExpiration()         // Date
```

### Key Fields

| Field | Type | Description |
|---|---|---|
| `keyId` | String | REQUIRED. Opaque key identifier |
| `signingAlgorithm` | SigningAlgorithm | HTTP-level algorithm (hs2019, rsa-sha256, etc.) |
| `algorithm` | Algorithm | Cryptographic algorithm (hmac-sha256, rsa-sha256, etc.) |
| `signature` | String | Base64-encoded signature value |
| `headers` | List<String> | HTTP headers included in signature (lowercase) |
| `parameterSpec` | AlgorithmParameterSpec | Optional (e.g., PSSParameterSpec for RSA-PSS) |

## Signer

Thread-safe, immutable. Create once and reuse across requests.

```java
Signer signer = new Signer(key, signature);
Signer signer = new Signer(key, signature, provider);       // custom Provider
Signer signer = new Signer(key, signature, provider, clock); // custom Clock for testing
```

```java
Signature signed = signer.sign(method, uri, headers);
String signingString = signer.createSigningString(method, uri, headers);
```

## Verifier

Create a new instance per signature to verify.

```java
Verifier verifier = new Verifier(key, signature);
Verifier verifier = new Verifier(key, signature, provider);
```

```java
boolean valid = verifier.verify(method, uri, headers);
```

## Algorithm Enum

31 cryptographic algorithms with portable and JVM names.

### HMAC (Symmetric)

| Portable Name | JVM Name | Notes |
|---|---|---|
| `hmac-sha1` | HmacSHA1 | |
| `hmac-sha224` | HmacSHA224 | |
| `hmac-sha256` | HmacSHA256 | Recommended |
| `hmac-sha384` | HmacSHA384 | |
| `hmac-sha512` | HmacSHA512 | |

### RSA (Asymmetric)

| Portable Name | JVM Name | Notes |
|---|---|---|
| `rsa-sha1` | SHA1withRSA | Deprecated |
| `rsa-sha256` | SHA256withRSA | |
| `rsa-sha384` | SHA384withRSA | |
| `rsa-sha512` | SHA512withRSA | |
| `rsa-sha3-256` | SHA3-256withRSA | |
| `rsa-sha3-384` | SHA3-384withRSA | |
| `rsa-sha3-512` | SHA3-512withRSA | |
| `rsassa-pss` | RSASSA-PSS | Requires AlgorithmParameterSpec |

### ECDSA (Elliptic Curve)

| Portable Name | JVM Name | Notes |
|---|---|---|
| `ecdsa-sha1` | SHA1withECDSA | |
| `ecdsa-sha256` | SHA256withECDSA | |
| `ecdsa-sha384` | SHA384withECDSA | |
| `ecdsa-sha512` | SHA512withECDSA | |
| `ecdsa-sha3-256` | SHA3-256withECDSA | |
| `ecdsa-sha3-384` | SHA3-384withECDSA | |
| `ecdsa-sha3-512` | SHA3-512withECDSA | |
| `ecdsa-sha256-p1363` | SHA256withECDSAinP1363Format | |
| `ecdsa-sha384-p1363` | SHA384withECDSAinP1363Format | |
| `ecdsa-sha512-p1363` | SHA512withECDSAinP1363Format | |

### DSA

| Portable Name | JVM Name |
|---|---|
| `dsa-sha1` | SHA1withDSA |
| `dsa-sha224` | SHA224withDSA |
| `dsa-sha256` | SHA256withDSA |
| `dsa-sha384` | SHA384withDSA |
| `dsa-sha512` | SHA512withDSA |
| `dsa-sha3-256` | SHA3-256withDSA |
| `dsa-sha3-384` | SHA3-384withDSA |
| `dsa-sha3-512` | SHA3-512withDSA |

```java
Algorithm alg = Algorithm.get("hmac-sha256");   // parse from either format
alg.getPortableName()   // "hmac-sha256"
alg.getJvmName()        // "HmacSHA256"
alg.getType()           // Mac.class or java.security.Signature.class
```

## SigningAlgorithm Enum

HTTP-level algorithm identifiers (what appears in the Authorization header).

| Value | Algorithm Name | Description |
|---|---|---|
| `HS2019` | hs2019 | Recommended. Actual algorithm derived from keyId metadata |
| `RSA_SHA256` | rsa-sha256 | Legacy |
| `ECDSA_SHA256` | ecdsa-sha256 | Legacy |
| `HMAC_SHA256` | hmac-sha256 | Legacy |
| `RSA_SHA1` | rsa-sha1 | Deprecated |

Use `HS2019` for new implementations.

## Special Pseudo-Headers

Include these in the `headers` list for the signing string:

| Pseudo-Header | Signing String Line | Description |
|---|---|---|
| `(request-target)` | `(request-target): post /api/foo` | HTTP method + URI |
| `(created)` | `(created): 1591763110` | Signature creation (seconds since epoch) |
| `(expires)` | `(expires): 1591766710` | Signature expiration (seconds since epoch) |

```java
Arrays.asList("(request-target)", "(created)", "(expires)", "host", "digest")
```

## Key Loading — PEM

Read PEM-encoded keys without Bouncy Castle:

```java
PrivateKey privateKey = PEM.readPrivateKey(new FileInputStream("private.pem"));
PublicKey publicKey = PEM.readPublicKey(new FileInputStream("public.pem"));
```

Supported PEM formats:
- `BEGIN RSA PRIVATE KEY` (PKCS#1)
- `BEGIN EC PRIVATE KEY` (EC PKCS#8)
- `BEGIN PRIVATE KEY` (PKCS#8)
- `BEGIN PUBLIC KEY` (X.509)
- `BEGIN CERTIFICATE` (X.509 certificate)

## Key Loading — RSA / EC Utilities

```java
// RSA from DER bytes
RSA.privateKeyFromPKCS8(derBytes)
RSA.privateKeyFromPKCS1(derBytes)
RSA.publicKeyFrom(derBytes)

// EC from DER bytes
EC.privateKeyFromPKCS8(derBytes)
EC.publicKeyFrom(derBytes)
```

## RSA Signing Example

```java
PrivateKey privateKey = PEM.readPrivateKey(new FileInputStream("private.pem"));

Signature signature = new Signature("rsa-key-1", "hs2019", "rsa-sha256", null,
    Arrays.asList("(request-target)", "host", "date"));

Signer signer = new Signer(privateKey, signature);
Signature signed = signer.sign("GET", "/resource", headers);

// Verification
PublicKey publicKey = PEM.readPublicKey(new FileInputStream("public.pem"));
Signature parsed = Signature.fromString(signed.toString(), Algorithm.RSA_SHA256);
Verifier verifier = new Verifier(publicKey, parsed);
boolean valid = verifier.verify("GET", "/resource", headers);
```

## Authorization Header Format

```
Authorization: Signature keyId="my-key",algorithm="hs2019",
  created=1591763110,expires=1591766710,
  headers="(created) (expires) (request-target) host content-length",
  signature="Base64EncodedValue=="
```

Fields: `keyId` (required), `algorithm` (required), `headers` (required), `signature` (required), `created` (optional), `expires` (optional).

## Exceptions

All extend `AuthenticationException` (RuntimeException):

| Exception | Cause |
|---|---|
| `MissingKeyIdException` | `keyId` missing from header |
| `MissingAlgorithmException` | `algorithm` missing from header |
| `MissingSignatureException` | `signature` missing from header |
| `MissingRequiredHeaderException` | Required header missing from HTTP message |
| `UnparsableSignatureException` | Malformed Authorization header |
| `UnsupportedAlgorithmException` | Algorithm not available |
| `InvalidCreatedFieldException` | `(created)` field in the future |
| `InvalidExpiresFieldException` | `(expires)` field in the past |

## Key Conventions

- Header names are normalized to lowercase internally
- Input headers can be any case
- Signer is thread-safe and reusable; create new Verifier per signature
- Use `Clock` injection for deterministic testing
- Signature objects are immutable
