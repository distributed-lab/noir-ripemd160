# Ripemd160 in Noir
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## How to use?

### Add dependency to your project's `Nargo.toml`

```toml
[dependencies]
ripemd160 = { tag = "v0.0.2", git = "https://github.com/distributed-lab/noir-ripemd160" }
```

### Employ in your `Noir` code as following

```rust
use ripemd160::ripemd160;

...

// Example
ripemd160(data);
```

## Library Overview

### Functions

- `ripemd160` - Accepts an array of bytes with any length and return 20-bytes array as hash. Data must be represented in big-endian order

- `byte_array_to_hex` - Converts bytes array to hex string. Accepts 20-bytes array

### Structs

- `Ripemd160Hasher` - Implements [std::hash::Hasher](https://github.com/noir-lang/noir/blob/master/noir_stdlib/src/hash/mod.nr#L159) trait
