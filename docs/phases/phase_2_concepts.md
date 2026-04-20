# Phase 2 Concepts: Why a Reference Backend and How It Works

**Status: IMPLEMENTED**

## Why does a reference backend exist?

If you are building a library that wraps a C library (SuiteSparse:GraphBLAS), you might ask: why not just go straight to the native code?

Three reasons:

### 1. Correctness needs an oracle

When the SuiteSparse backend produces a result, how do you know it is correct? You need something to compare against. That something is the reference backend.

The reference backend is intentionally simple. It uses the most straightforward possible implementation of each operation. It is designed so that a human can read the code and verify correctness by hand. When the native backend produces a different result, the reference backend is the ground truth that decides which one is wrong.

### 2. API design needs validation

Before committing to a native implementation, you want to be sure the API is right. The reference backend lets you:

- Use the API in real scenarios (tests, examples, tutorials)
- Discover awkward edges (bad ergonomic choices, missing operations, confusing defaults)
- Validate that the backend behaviour contract is complete and well-typed

If the reference backend is hard to use correctly, the native backend will be hard to use correctly too. Fix the API first, then make it fast.

### 3. Teaching needs simplicity

GraphBLAS concepts (semirings, monoids, masks, descriptors) are unfamiliar to most Elixir developers. The reference backend provides the simplest possible implementation of each concept. A reader can look at `GraphBLAS.Backend.Elixir.matrix_mxm/4` and understand exactly what semiring multiplication computes: multiply matching pairs, combine the products.

You cannot do this with a native backend. The Zigler NIF module that calls `GrB_mxm` tells you nothing about what the operation means. It only tells you that a C function was called.

## How the reference backend represents data

### Matrices: flat tuple-key maps

A sparse matrix with entries at (0,1)=5, (1,2)=7, (2,0)=3 is stored as:

```elixir
%{
  entries: %{{0, 1} => 5, {1, 2} => 7, {2, 0} => 3},
  nrows: 3,
  ncols: 3,
  type: :int64
}
```

Why this representation?

1. **Single-level lookup**: `matrix.data.entries[{0, 1}]` returns `5` in O(1) average time.
2. **Trivial pattern matching**: You can inspect, serialize, and debug any matrix by iterating `matrix.data.entries`.
3. **Trivial COO extraction**: `Enum.map(entries, fn {{r, c}, v} -> {r, c, v} end)` gives you COO triples.
4. **Trivial construction from COO**: `Enum.reduce(triples, %{}, fn {r, c, v}, acc -> Map.put(acc, {r, c}, v) end)`.

The trade-off: accessing all entries in a single row requires `Enum.filter(entries, fn {{r, _}, _} -> r == row end)`, which is O(nnz) rather than O(nnz_per_row). This is fine. The reference backend is not optimized for row access patterns. It is optimized for clarity.

### Vectors: flat maps

A sparse vector with entries at index 0=4, index 2=8 is stored as:

```elixir
%{
  entries: %{0 => 4, 2 => 8},
  size: 4,
  type: :int64
}
```

Same reasoning: single-level lookup, trivial inspection, trivial serialization.

### Why NOT nested maps?

Phase 1 used `%{row => %{col => value}}` for matrices. This representation has a small advantage for row-based access patterns (you can get an entire row in O(1)), but:

- It requires two-level map operations for every matrix operation
- It is harder to inspect in debugging (nested maps are harder to read)
- It complicates COO extraction (requires `Enum.flat_map` over nested structures)
- It provides no correctness benefit over flat maps

Flat tuple-key maps are simpler. Simplicity is the primary goal of the reference backend.

### Why NOT dense arrays?

Dense arrays (list-of-lists, Elixir arrays, etc.) would make element access O(1) but would require O(n*m) storage for an n-by-m matrix, even when most entries are zero. That violates the sparse requirement. The reference backend stores only explicit entries.

We provide `Matrix.to_dense/1` and `Vector.to_list/1` as debugging helpers, but these materialize all zeros and are for inspection only, not computation.

## How semirings work in the reference backend

### What is a semiring, again?

A semiring `(S, multiply, add, add_identity, multiply_identity)` has:
- A set of values (e.g., all integers)
- A multiply operator (e.g., `a * b`)
- An add operator (e.g., `a + b`)
- An add identity (e.g., 0 for addition)
- A multiply identity (e.g., 1 for multiplication)

The multiply distributes over add, and add identity is an annihilator for multiply.

### How mxm uses a semiring

Matrix multiplication `C = A mxm B` with semiring `(multiply, add)`:

```
For each (i, j) where C[i,j] might be non-zero:
  C[i,j] = add over all k where A[i,k] and B[k,j] are both stored:
             multiply(A[i,k], B[k,j])
```

In the reference backend, this is:

```elixir
# Pseudocode for mxm with flat tuple-key maps
for each {i, k, a_val} in A.entries:
  for each {k', j, b_val} in B.entries where k' == k:
    product = multiply.(a_val, b_val)
    C_entries[{i, j}] = add.(C_entries[{i, j}] || add_identity, product)
```

This double-loop is the most straightforward implementation possible. It is not fast for large matrices, but it is provably correct.

### Changing the semiring changes the algorithm

- `plus_times`: standard matrix multiplication (for computing paths, degrees)
- `lor_land`: boolean reachability (for BFS, transitive closure)
- `min_plus`: shortest path (for weighted shortest path)
- `max_min`: capacity/bottleneck (for maximum flow problems)

Same `mxm` function, different semiring, completely different algorithm. This is the core insight of GraphBLAS, and the reference backend makes it tangible.

## How ewise operations work

### ewise_add: union of structural positions

`ewise_add(A, B, monoid)` produces a matrix with entries at every position that exists in either A or B. Where both have entries, the monoid combines them.

```elixir
# Pseudocode
for each {ij, a_val} in A.entries:
  if B.entries has ij:
    result[ij] = monoid_operator.(a_val, B.entries[ij])
  else:
    result[ij] = a_val

for each {ij, b_val} in B.entries where ij not in A.entries:
  result[ij] = b_val
```

In Elixir, this is `Map.merge(a_entries, b_entries, fn _k, v1, v2 -> op.(v1, v2) end)`.

### ewise_mult: intersection of structural positions

`ewise_mult(A, B, monoid)` produces a matrix with entries only at positions that exist in both A and B.

```elixir
# Pseudocode
for each {ij, a_val} in A.entries:
  if B.entries has ij:
    result[ij] = monoid_operator.(a_val, B.entries[ij])
```

In Elixir, this is `Map.intersect(a_entries, b_entries, fn _k, v1, v2 -> op.(v1, v2) end)`.

These two operations are to sparse algebra what UNION and INTERSECTION are to set theory. The reference backend makes this analogy concrete.

## Dense conversion helpers

### Matrix.to_dense/1

Returns a list-of-lists representation where missing entries are filled with the additive identity (0 for numeric types, false for bool):

```elixir
{:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 2}], :int64)
GraphBLAS.Matrix.to_dense(m)
# => [[0, 1, 0], [0, 0, 2], [0, 0, 0]]
```

### Vector.to_list/1

Returns a list where missing entries are filled with the additive identity:

```elixir
{:ok, v} = GraphBLAS.Vector.from_entries(3, [{0, 5}, {2, 7}], :int64)
GraphBLAS.Vector.to_list(v)
# => [5, 0, 7]
```

These helpers are for debugging and documentation. They materialize default values. They should NOT be used in hot code paths.

## How the reference backend will validate the native backend

In Phase 4 (parity validation), we will run the same inputs through both backends and compare outputs:

```elixir
# Future parity test (Phase 4)
for inputs <- test_cases() do
  {:ok, ref_result} = GraphBLAS.Matrix.mxm(a, b, semiring, backend: GraphBLAS.Backend.Elixir)
  {:ok, nat_result} = GraphBLAS.Matrix.mxm(a, b, semiring, backend: GraphBLAS.Backend.SuiteSparse)
  assert results_equal?(ref_result, nat_result)
end
```

The reference backend defines what "correct" means. The native backend must match it exactly (up to floating-point precision for `:fp64` and `:fp32` types).