# Phase 2 Release Notes (Draft)

**Status: IMPLEMENTED**

## Version 0.2.0 — Pure Elixir Reference Backend

### Namespace change

All public modules have been renamed from `ExGraphBLAS.*` to `GraphBLAS.*`:

| Before (v0.1.0) | After (v0.2.0) |
|------------------|----------------|
| `ExGraphBLAS.Matrix` | `GraphBLAS.Matrix` |
| `ExGraphBLAS.Vector` | `GraphBLAS.Vector` |
| `ExGraphBLAS.Scalar` | `GraphBLAS.Scalar` |
| `ExGraphBLAS.Semiring` | `GraphBLAS.Semiring` |
| `ExGraphBLAS.Monoid` | `GraphBLAS.Monoid` |
| `ExGraphBLAS.BinaryOp` | `GraphBLAS.BinaryOp` |
| `ExGraphBLAS.UnaryOp` | `GraphBLAS.UnaryOp` |
| `ExGraphBLAS.Mask` | `GraphBLAS.Mask` |
| `ExGraphBLAS.Descriptor` | `GraphBLAS.Descriptor` |
| `ExGraphBLAS.Backend` | `GraphBLAS.Backend` |
| `ExGraphBLAS.Backend.Reference` | `GraphBLAS.Backend.Elixir` |
| `ExGraphBLAS.Backend.SuiteSparse` | `GraphBLAS.Backend.SuiteSparse` |
| `ExGraphBLAS.Types` | `GraphBLAS.Types` |
| `ExGraphBLAS.Error` | `GraphBLAS.Error` |
| `ExGraphBLAS.Config` | `GraphBLAS.Config` |

The application name remains `:ex_graphblas`. The Hex package name remains `ex_graphblas`.

### Backend rename

`ExGraphBLAS.Backend.Reference` is now `GraphBLAS.Backend.Elixir`. The name "Elixir" communicates that this is a pure Elixir implementation with no native code. It is correct but not performant.

### Representation change

The internal data representation for matrices has been simplified:

- **Before**: `%{row => %{col => value}}` (nested maps)
- **After**: `%{{row, col} => value}` (flat tuple-key maps)

Vector representation remains `%{index => value}`.

This change makes the reference backend easier to inspect, debug, and reason about. It is not a performance optimization.

### New functions

#### `GraphBLAS.Matrix.to_dense/1`

Returns a list-of-lists representation of the matrix, with default values (zeros) filled in.

```elixir
{:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 2}], :int64)
GraphBLAS.Matrix.to_dense(m)
# => [[0, 1, 0], [0, 0, 2], [0, 0, 0]]
```

**This function is for debugging and documentation only. Do not use it in production code paths.** It materializes all default values and creates large lists for big matrices.

#### `GraphBLAS.Vector.to_list/1`

Returns a list representation of the vector, with default values filled in.

```elixir
{:ok, v} = GraphBLAS.Vector.from_entries(3, [{0, 5}, {2, 7}], :int64)
GraphBLAS.Vector.to_list(v)
# => [5, 0, 7]
```

**Same warning as above: debugging and documentation only.**

### Semantic correctness test suite

Phase 2 adds hand-verified test cases for every operation. Each test:
1. States the mathematical operation being tested
2. Shows the expected result computed by hand
3. Verifies the Elixir backend produces the exact same result

This test suite will serve as the regression baseline for Phase 4 (SuiteSparse parity validation).

### What you can do now

Everything from Phase 1, plus:

```elixir
# Dense matrix inspection (for debugging)
{:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 2}, {2, 0, 3}], :int64)
GraphBLAS.Matrix.to_dense(m)
# => [[0, 1, 0], [0, 0, 2], [3, 0, 0]]

# Dense vector inspection (for debugging)
{:ok, v} = GraphBLAS.Vector.from_entries(4, [{0, 1.0}, {2, 3.0}], :fp64)
GraphBLAS.Vector.to_list(v)
# => [1.0, 0.0, 3.0, 0.0]
```

### What you cannot do yet

- **Native execution**: All computation runs in the Elixir backend. No NIFs, no SuiteSparse.
- **Masked operations**: Mask and Descriptor types exist but are not wired into compute operations.
- **Graph algorithms**: No BFS, PageRank, etc.
- **Nx integration**: No conversion to/from Nx tensors.
- **Performance**: The Elixir backend is intentionally not optimized for large matrices.

### Known limitations

1. **Performance**: The reference backend uses Elixir maps. It is correct but slow for matrices with more than a few thousand entries. Do not benchmark it and draw conclusions about the library's ceiling.

2. **Memory**: Dense conversion helpers (`to_dense`, `to_list`) materialize all default values. Do not use them on large matrices/vectors.

3. **Representation**: Flat tuple-key maps make row-based access O(nnz) per row. This is fine for correctness and debugging, but would be inefficient for algorithms that need fast row slicing. Such algorithms should use the native backend (Phase 3).

### Design decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend name | `GraphBLAS.Backend.Elixir` | Clearly communicates "pure Elixir, no native code" |
| Matrix representation | `%{{row, col} => value}` | Single-level lookup, trivially inspectable, simplest correct implementation |
| Vector representation | `%{index => value}` | Already simple, no change needed |
| Namespace | `GraphBLAS` | Matches prompt specification; shorter and clearer than `ExGraphBLAS` |
| Dense helpers | Debug-only | Materializing default values is wasteful; helpers exist for inspection only |
| Semantic tests | Hand-verified | Each test has explicit expected output, not just "it doesn't crash" |