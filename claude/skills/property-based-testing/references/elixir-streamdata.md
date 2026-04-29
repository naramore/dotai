# Elixir — `StreamData`

**Library:** [hex.pm/packages/stream_data](https://hex.pm/packages/stream_data) — first-party, by the Elixir core team. Integrates with ExUnit via `ExUnitProperties`. Composable generators with automatic shrinking.

## Installation (`mix.exs`)

```elixir
defp deps do
  [
    {:stream_data, "~> 1.0", only: [:test, :dev]}
  ]
end
```

## Round-trip property

```elixir
defmodule SerializerPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "JSON round-trip preserves data" do
    check all map <- map_of(string(:alphanumeric), integer()) do
      assert map |> Jason.encode!() |> Jason.decode!() == map
    end
  end
end
```

## Validity + invariant properties

```elixir
property "sorting produces a sorted list" do
  check all list <- list_of(integer()) do
    sorted = Enum.sort(list)
    assert sorted == Enum.sort(sorted)               # idempotency
    assert length(sorted) == length(list)             # preservation
    sorted
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [a, b] -> assert a <= b end)      # actually sorted
  end
end
```

## Custom generator

```elixir
defmodule Generators do
  use ExUnitProperties

  def user_gen do
    gen all name <- string(:alphanumeric, min_length: 1, max_length: 50),
            age <- integer(0..150),
            email <- email_gen(),
            active <- boolean() do
      %{name: name, age: age, email: email, active: active}
    end
  end

  def email_gen do
    gen all local <- string(:alphanumeric, min_length: 1, max_length: 20),
            domain <- string(:alphanumeric, min_length: 1, max_length: 10),
            tld <- member_of(["com", "org", "net", "io"]) do
      "#{local}@#{domain}.#{tld}"
    end
  end
end
```

## Generator validity test

```elixir
property "user generator produces valid users" do
  check all user <- Generators.user_gen() do
    assert valid_user?(user), "generator produced invalid user: #{inspect(user)}"
  end
end
```

## CI configuration

Set the iteration count via `ExUnitProperties` options or a module attribute:

```elixir
@moduletag timeout: 60_000

property "expensive property", max_runs: 200 do
  # ...
end
```
