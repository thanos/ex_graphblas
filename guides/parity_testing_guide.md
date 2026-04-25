# Parity Testing Guide: How to Verify Two Backends Agree

**Status: IMPLEMENTED**

## Why parity testing exists

This library has two backends: a pure Elixir reference backend (correct by inspection) and a SuiteSparse native backend (fast by design). They implement the same mathematical operations using completely different algorithms and data structures.

If they disagree, the Elixir backend is right — by definition, because it is simple enough to verify by reading the code. The SuiteSparse backend is valuable only because it produces the same results faster.

Parity testing is the proof that both backends agree.

## The parity test pattern

Every parity test follows the same five-step pattern:

```elixir
test "mxm parity: plus_times with int64" do
  # 1. Create identical inputs with both backends
  {:ok, ref_a} = RefBackend.matrix_from_coo(3, 3, entries_a, :int64, [])
  {:ok, ss_a} = SuiteSparse.matrix_from_coo(3, 3, entries_a, :int64, [])

  # 2. Perform the same operation
  {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_a, :plus_times, [])
  {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_a, :plus_times, [])

  # 3. Extract results
  {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
  {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

  # 4. Compare results
  assert sort_coo(ref_coo) == sort_coo(ss_coo)

  # 5. Free SuiteSparse objects
  SuiteSparse.matrix_free(ss_a)
  SuiteSparse.matrix_free(ss_c)
end
```

Steps 1-3 are the same regardless of the operation. Step 4 differs for `:fp64` (use `assert_in_delta`). Step 5 is always required for SuiteSparse objects.

## Parameterized test generation

Rather than writing 150+ individual tests by hand, we generate them from data structures:

```elixir
@semiring_mxm_cases [
  {:plus_times, :int64, [{0, 1, 2}, {1, 0, 3}], [{0, 0, 10}, {0, 1, 4}, {1, 0, 3}]},
  {:plus_times, :fp64, [{0, 1, 1.5}, {1, 0, 2.5}], [{0, 0, 3.75}]},
  {:lor_land, :bool, [{0, 1, true}, {1, 0, true}], [{0, 0, true}, {0, 1, true}]},
  # ... etc
]

for {semiring, type, input, expected} <- @semiring_mxm_cases do
  @tag semiring: semiring, type: type
  test "mxm with #{semiring} / #{type}" do
    # Generate test using input and expected
  end
end
```

This ensures every combination is tested. Adding a new semiring or type requires only updating the data structure.

## Comparison rules

### Exact equality (`:int64`, `:bool`)

For integer and boolean types, we require exact equality:

```elixir
assert sort_coo(ref_coo) == sort_coo(ss_coo)
```

COO entries are sorted by `(row, col)` before comparison because the two backends may produce entries in different orders.

### Approximate equality (`:fp64`)

For floating-point types, we use `assert_in_delta`:

```elixir
assert_coo_approx_equal(ref_coo, ss_coo, 0.001)

defp assert_coo_approx_equal(ref, ss, delta) do
  ref_sorted = sort_coo(ref)
  ss_sorted = sort_coo(ss)
  assert length(ref_sorted) == length(ss_sorted)
  Enum.zip_with(ref_sorted, ss_sorted, fn {r1, c1, v1}, {r2, c2, v2} ->
    assert r1 == r2
    assert c1 == c2
    assert_in_delta v1, v2, delta
  end)
end
```

The tolerance of 0.001 is generous. For chain multiplications (mxm), a larger tolerance may be needed.

### Sorting

COO format does not guarantee entry order. The Elixir backend stores entries in insertion order with deduplication. SuiteSparse stores entries in column-major order. We sort by `(row, col)` before comparing:

```elixir
defp sort_coo(entries) do
  Enum.sort_by(entries, fn {r, c, _v} -> {r, c} end)
end
```

## Memory management in tests

The SuiteSparse backend requires explicit memory management. Every SuiteSparse object created in a test must be freed:

```elixir
# At the end of every parity test:
SuiteSparse.matrix_free(ss_a)
SuiteSparse.matrix_free(ss_result)
# For vectors:
SuiteSparse.vector_free(ss_v)
```

The Elixir backend's objects are BEAM data structures and are garbage collected normally. No freeing is needed.

## Test isolation

All parity tests use `async: false` because SuiteSparse:GraphBLAS is not thread-safe. Running SuiteSparse operations concurrently from multiple processes could cause data corruption.

```elixir
defmodule GraphBLAS.Backend.ParityTest do
  use ExUnit.Case, async: false  # Required for SuiteSparse
```

## The test matrix

### Semiring operations tested by operation

| Operation | Semirings | Types | Tests |
|-----------|-----------|-------|-------|
| `mxm` | All 10 | Per semiring | ~20 |
| `mxv` | All 10 | Per semiring | ~20 |
| `vxm` | All 10 | Per semiring | ~20 |
| `ewise_add` | All 11 monoids | Per monoid | ~25 |
| `ewise_mult` | All 11 monoids | Per monoid | ~25 |
| `reduce (matrix)` | All 11 monoids | Per monoid | ~25 |
| `reduce (vector)` | All 11 monoids | Per monoid | ~25 |

### Edge cases tested

| Category | Tests |
|----------|-------|
| Empty matrix/vector | ~10 |
| Single-element | ~5 |
| Identity matrix | ~3 |
| Zero matrix | ~5 |
| Duplicate COO entries | ~8 |
| Error paths | ~5 |
| Semantic correctness | ~15 |

### Total: 350+ tests across all suites

## Debugging parity failures

When a parity test fails, the two backends disagree. Here is the debugging process:

1. **Determine which backend is wrong**: The Elixir backend is the oracle. If SuiteSparse disagrees, SuiteSparse is wrong. But verify this — check the expected result manually.

2. **Check the semiring/monoid mapping**: The most common bug is an incorrect mapping between Elixir atoms and SuiteSparse constants. Verify the integer code in `@semiring_codes` and `@monoid_codes` matches the Zig NIF's `semiring_from_code` and `monoid_from_code` functions.

3. **Check the type mapping**: Ensure the `type_to_code` mapping in the Elixir backend matches the Zig NIF's `type_code_to_grb_type` function.

4. **Check duplicate handling**: Both backends must combine duplicate COO entries using the same monoid operator. If they differ, check which monoid is being used for `matrix_build`.

5. **Check floating-point precision**: For `:fp64` tests, verify the tolerance is appropriate. If the difference is tiny (e.g., 1e-15), it may be a floating-point rounding difference, not a bug.

6. **Check empty handling**: Reducing an empty collection should return the monoid's identity element. Verify both backends agree on what that identity is.

## Property-based testing with StreamData

In addition to deterministic parity tests, Phase 4 introduces property-based testing using StreamData. Property tests generate random sparse matrices and vectors, then verify that algebraic properties hold for all generated inputs.

### How to write a property test

```elixir
defmodule GraphBLAS.PropertyTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias GraphBLAS.Backend.Elixir, as: RefBackend
  alias GraphBLAS.Backend.SuiteSparse

  property "mxm parity holds for random int64 matrices" do
    check all entries <- sparse_int64_matrix(5, 5, max_density: 0.3) do
      {:ok, ref_a} = RefBackend.matrix_from_coo(5, 5, entries, :int64, [])
      {:ok, ss_a} = SuiteSparse.matrix_from_coo(5, 5, entries, :int64, [])

      {:ok, ref_b} = RefBackend.matrix_from_coo(5, 5, entries, :int64, [])
      {:ok, ss_b} = SuiteSparse.matrix_from_coo(5, 5, entries, :int64, [])

      {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times, [])
      {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :plus_times, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)

      SuiteSparse.matrix_free(ss_a)
      SuiteSparse.matrix_free(ss_b)
      SuiteSparse.matrix_free(ss_c)
    end
  end
end
```

### Generators

StreamData generators produce random values. For sparse matrix testing, we need generators that produce valid COO entries:

```elixir
# Generator for sparse int64 matrix entries
defp sparse_int64_matrix(rows, cols, opts) do
  density = Keyword.get(opts, :max_density, 0.5)
  StreamData.list_of(
    StreamData.tuple({
      StreamData.integer(0..(rows - 1)),
      StreamData.integer(0..(cols - 1)),
      StreamData.integer(-100..100)
    }),
    min: 0,
    max: trunc(rows * cols * density)
  )
end
```

### Shrinking

When a property test fails, StreamData automatically shrinks the input to the minimal counterexample. For example, if a 20-entry matrix causes a parity failure, StreamData will reduce it to the smallest matrix that still fails. This is invaluable for debugging.

### What properties to test

1. **Parity**: For any valid input, both backends produce identical results
2. **Identity**: `reduce(empty, M)` = `M.identity` for any monoid M
3. **Associativity**: `(A mxm B) mxm C` = `A mxm (B mxm C)` for matrix multiplication
4. **Distributivity**: `A mxm (B ewise_add C)` = `(A mxm B) ewise_add (A mxm C)` for relevant semirings