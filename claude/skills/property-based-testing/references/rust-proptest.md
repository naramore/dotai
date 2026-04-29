# Rust — `proptest`

**Library:** [crates.io/crates/proptest](https://crates.io/crates/proptest) — Hypothesis-inspired with integrated shrinking. Derive macros via `proptest-derive`. Auto-saves regression files.

## Installation (`Cargo.toml`)

```toml
[dev-dependencies]
proptest = "1"
proptest-derive = "0.5"
```

## Round-trip property

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_serialize_round_trip(value: i64) {
        let bytes = serialize(value);
        let decoded = deserialize(&bytes).unwrap();
        prop_assert_eq!(decoded, value);
    }
}
```

## Derived `Arbitrary`

```rust
use proptest::prelude::*;
use proptest_derive::Arbitrary;

#[derive(Debug, Clone, PartialEq, Arbitrary)]
struct User {
    #[proptest(regex = "[a-zA-Z]{1,20}")]
    name: String,
    #[proptest(strategy = "0u32..=150")]
    age: u32,
    active: bool,
}

proptest! {
    #[test]
    fn test_user_serde_round_trip(user: User) {
        let json = serde_json::to_string(&user).unwrap();
        let decoded: User = serde_json::from_str(&json).unwrap();
        prop_assert_eq!(decoded, user);
    }
}
```

## Custom strategy + generator validity test

```rust
use proptest::prelude::*;

fn valid_email() -> impl Strategy<Value = String> {
    "[a-z]{1,10}@[a-z]{1,10}\\.[a-z]{2,4}".prop_map(|s| s)
}

proptest! {
    #[test]
    fn test_email_validation(email in valid_email()) {
        prop_assert!(validate_email(&email).is_ok(),
            "valid email rejected: {}", email);
    }
}
```

## Regression files

`proptest` automatically saves failing inputs to `proptest-regressions/` files. **Commit these to the repo** so the same case is replayed first on every run.

## CI configuration

```rust
proptest! {
    #![proptest_config(ProptestConfig::with_cases(200))]
    #[test]
    fn test_in_ci(x: i32) {
        // ...
    }
}
```
