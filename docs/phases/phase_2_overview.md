# Phase 2 Overview: Pure Elixir Reference Backend

**Status: IMPLEMENTED**

## Why this phase exists

Phase 1 established the architecture: a backend-neutral public API, a behaviour contract, and a working but minimal Reference backend. That backend was enough to prove the architecture works, but it was not designed to be a semantic oracle.

Phase 2 turns the reference backend into a **correctness-first, fully inspectable implementation** that will serve four critical roles:

1. **Semantic oracle**: Every operation produces an authoritative result that future native backends must match exactly.
2. **Regression baseline**: When the SuiteSparse backend arrives (Phase 3), it must produce identical outputs for identical inputs. The reference backend defines what "identical" means.
3. **Tutorial vehicle**: The simplest readable implementation of each GraphBLAS operation. A new contributor should be able to read `GraphBLAS.Backend.Elixir` and understand what `mxm` computes.
4. **API validation**: If we cannot express an operation clearly in pure Elixir, the API design needs rethinking.

## What will be built

### Namespace rename

Every module moves from `ExGraphBLAS.*` to `GraphBLAS.*`:

- `ExGraphBLAS.Matrix` becomes `GraphBLAS.Matrix`
- `ExGraphBLAS.Backend.Reference` becomes `GraphBLAS.Backend.Elixir`
- etc.

The application name (`:ex_graphblas`) stays the same. Only the module namespace changes.

### Representation simplification

The current Reference backend uses nested maps for matrix storage:

```elixir
# Current (Phase 1): two-level lookup
%{entries: %{0 => %{1 => 1, 2 => 2}, 1 => %{0 => 3}}, nrows: 3, ncols: 3, type: :int64}
```

Phase 2 simplifies this to flat tuple-key maps:

```elixir
# Phase 2: single-level lookup, more inspectable
%{entries: %{{0, 1} => 1, {0, 2} => 2, {1, 0} => 3}, nrows: 3, ncols: 3, type: :int64}
```

For vectors, the representation remains `%{index => value}`.

Why flat maps? Because:
- They are trivially pattern-matchable: `map[{0, 1}]` gives you the value at (0,1)
- They are trivially serializable for debugging
- They make COO extraction a single `Enum.map` over map entries
- They make every operation easier to reason about

This is NOT a performance choice. It is a clarity choice.

### Backend rename

`ExGraphBLAS.Backend.Reference` becomes `GraphBLAS.Backend.Elixir`. The name "Elixir" communicates two things:
- This is the pure Elixir implementation (no native code)
- This is the canonical reference for correct behavior

The `SuiteSparse` backend placeholder also gets renamed to `GraphBLAS.Backend.SuiteSparse`.

### Dense conversion helpers

Two new functions for debugging and documentation:

```elixir
# Returns a list-of-lists representation (row-major, 0-indexed)
GraphBLAS.Matrix.to_dense(matrix)
# => [[0, 1, 0], [0, 0, 2], [3, 0, 0]]

# Returns a list representation (0-indexed)
GraphBLAS.Vector.to_list(vector)
# => [0, 1, 3]
```

These are for debugging and tutorials only. They materialize the default values (zeros) that sparse storage omits. They should NOT be used in production code paths.

### Semantic correctness test suite

Every operation gets hand-verified test cases with explicit expected values. Example:

```elixir
test "mxm with plus_times on adjacency matrix" do
  # Graph: 0 -> 1 -> 2 -> 0 (3-node directed cycle)
  # Adjacency matrix A:
  #   row 0: [0, 1, 0]
  #   row 1: [0, 0, 1]
  #   row 2: [1, 0, 0]
  #
  # A^2 (two-hop reachability with plus_times):
  #   (0,1)*(1,2) = 1*1 = 1 => (0,2)
  #   (1,2)*(2,0) = 1*1 = 1 => (1,0)
  #   (2,0)*(0,1) = 1*1 = 1 => (2,1)
  #
  # Expected: {(0,2): 1, (1,0): 1, (2,1): 1}
  ...
end
```

### Regression oracle framework

A test helper module that provides a consistent way to run the same inputs through any backend and compare outputs. This will be used in Phase 4 when we validate SuiteSparse parity.

## What will NOT be built

- No native/NIF code (Phase 3)
- No performance optimization (the reference backend is intentionally naive)
- No new operations beyond what Phase 1 defines
- No Nx integration (Phase 7)
- No graph algorithms (Phase 6)
- No masks or descriptors wired into operations (Phase 5)
- No concurrency or parallelism
- No CSR/CSC storage optimization

## How this phase relates to other phases

```
Phase 1 (done)     Architecture, API shape, scaffolding
Phase 2 (this)     Pure Elixir reference backend — semantic oracle
Phase 3             SuiteSparse native backend — performance
Phase 4             Parity validation between Elixir and SuiteSparse
Phase 5             Masks, descriptors, API honing
Phase 6             Graph algorithms
Phase 7             Nx integration
Phase 8             Hardening, benchmarks, release
```

The reference backend is the foundation for Phase 4 (parity testing) and the tutorial vehicle for all subsequent phases. Getting it right matters more than getting it fast.