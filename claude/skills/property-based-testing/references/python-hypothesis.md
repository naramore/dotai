# Python — `Hypothesis`

**Library:** [hypothesis.works](https://hypothesis.works/) — gold standard. Best-in-class shrinking, Conjecture-based engine, persistent failing-example database, large strategy ecosystem.

## Installation

```bash
pip install hypothesis
```

## Round-trip property

```python
from hypothesis import given, strategies as st
import json

@given(st.dictionaries(
    keys=st.text(min_size=1),
    values=st.one_of(st.integers(), st.text(), st.booleans(), st.none()),
))
def test_json_round_trip(data):
    assert json.loads(json.dumps(data)) == data
```

## Metamorphic properties

```python
from hypothesis import given, strategies as st

@given(st.lists(st.integers()))
def test_sort_preserves_length(xs):
    assert len(sorted(xs)) == len(xs)

@given(st.lists(st.integers()), st.integers())
def test_sort_append_invariant(xs, y):
    assert sorted(xs + [y]) == sorted([y] + xs)
```

## Composite strategy

```python
from hypothesis import given, strategies as st

@st.composite
def user_strategy(draw):
    return {
        "name": draw(st.text(min_size=1, max_size=50)),
        "age": draw(st.integers(min_value=0, max_value=150)),
        "email": draw(st.emails()),
        "active": draw(st.booleans()),
    }

@given(user_strategy())
def test_normalize_user_idempotent(user):
    once = normalize_user(user)
    twice = normalize_user(once)
    assert once == twice
```

## Generator validity test

```python
@given(user_strategy())
def test_user_strategy_produces_valid_users(user):
    assert is_valid_user(user), f"generator produced invalid user: {user}"
```

## CI configuration

```python
from hypothesis import settings

settings.register_profile("ci", max_examples=200, deadline=500)
settings.register_profile("dev", max_examples=1000)
settings.load_profile("ci")
```

Hypothesis stores failing examples in `.hypothesis/examples/` — commit this directory so regressions replay on every CI run.
