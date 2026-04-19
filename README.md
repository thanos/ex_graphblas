# GraphBLAS

An Elixir library for sparse linear algebra and graph computation inspired by the GraphBLAS model.

- Sparse matrices and vectors
- Semirings, monoids, masks, descriptors
- Graph algorithms expressed as linear algebra
- Native-performance execution where needed (Phase 2)
- Idiomatic Elixir data structures and documentation at the boundary

## Architecture

GraphBLAS is built around a **backend behaviour** that separates the public
API from the computation engine:

- `GraphBLAS.Matrix` / `GraphBLAS.Vector` -- public API modules
- `GraphBLAS.Backend` -- the behaviour defining the computation contract
- `GraphBLAS.Backend.Reference` -- a pure Elixir reference implementation
- `GraphBLAS.Backend.SuiteSparse` -- reserved for Phase 2 (Zigler-based native backend)

Select a backend via application config:

    config :ex_graphblas, default_backend: GraphBLAS.Backend.Reference

Or per-call:

    GraphBLAS.Matrix.from_coo(3, 3, entries, :int64, backend: MyBackend)

## Quick start

    # Create a sparse 3x3 matrix from COO triples
    {:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [
      {0, 1, 1}, {1, 2, 2}, {2, 0, 3}
    ], :int64)

    # Multiply it by itself
    {:ok, result} = GraphBLAS.Matrix.mxm(m, m, :plus_times)

    # Extract entries
    {:ok, entries} = GraphBLAS.Matrix.to_coo(result)

## Phase 1 scope

This is Phase 1: architecture, API shape, and scaffolding. It includes:

- Backend behaviour and reference implementation
- Matrix and vector construction, inspection, and core operations (mxm, mxv, vxm, ewise, reduce, transpose)
- Semirings and monoids (built-in set)
- Masks and descriptors (type definitions, full operations in Phase 4)
- Configuration mechanism for backend selection
- Full test suite for the reference backend

Not yet included:

- Native SuiteSparse backend (Phase 2)
- Masked operations (Phase 4)
- Graph algorithms (Phase 5)
- Nx integration (Phase 6)

## Installation

Add `ex_graphblas` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_graphblas, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ex_graphblas>.
