# Go — `rapid`

**Library:** [pgregory.net/rapid](https://github.com/flyingmutant/rapid) — modern, actively maintained, integrated shrinking, works with `testing.T`, zero dependencies.

## Installation

```bash
go get pgregory.net/rapid
```

## Round-trip property

```go
package mypackage

import (
    "testing"
    "pgregory.net/rapid"
)

func TestSerializeRoundTrip(t *testing.T) {
    rapid.Check(t, func(t *rapid.T) {
        user := User{
            Name:  rapid.String().Draw(t, "name"),
            Age:   rapid.IntRange(0, 150).Draw(t, "age"),
            Email: rapid.StringMatching(`[a-z]+@[a-z]+\.[a-z]{2,4}`).Draw(t, "email"),
        }

        data, err := Serialize(user)
        if err != nil {
            t.Fatal(err)
        }
        got, err := Deserialize(data)
        if err != nil {
            t.Fatal(err)
        }

        if got != user {
            t.Fatalf("round-trip failed: got %v, want %v", got, user)
        }
    })
}
```

## Metamorphic property — sort idempotency

```go
func TestSortIdempotent(t *testing.T) {
    rapid.Check(t, func(t *rapid.T) {
        xs := rapid.SliceOf(rapid.Int()).Draw(t, "xs")

        sorted1 := Sort(append([]int{}, xs...))
        sorted2 := Sort(append([]int{}, sorted1...))

        if !slices.Equal(sorted1, sorted2) {
            t.Fatalf("sort is not idempotent")
        }
    })
}
```

## Custom generator + generator validity test

```go
func genUser(t *rapid.T) User {
    return User{
        Name:   rapid.StringMatching(`[A-Z][a-z]{1,20}`).Draw(t, "name"),
        Age:    rapid.IntRange(0, 150).Draw(t, "age"),
        Active: rapid.Bool().Draw(t, "active"),
    }
}

// Generator validity: confirm genUser only produces valid users.
func TestGenUserProducesValidUsers(t *testing.T) {
    rapid.Check(t, func(t *rapid.T) {
        user := genUser(t)
        if err := validateUser(user); err != nil {
            t.Fatalf("generator produced invalid user: %+v, error: %v", user, err)
        }
    })
}
```

## CI configuration

`rapid` reads `RAPID_CHECKS`, `RAPID_STEPS`, `RAPID_SEED` from env — set lower check counts in CI:

```bash
RAPID_CHECKS=200 go test ./...
```
