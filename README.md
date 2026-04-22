# GraphBLAS

An Elixir library for sparse linear algebra and graph computation, inspired by the GraphBLAS standard.

GraphBLAS provides idiomatic Elixir data structures at the boundary while delegating computation to swappable backends. The same code runs on a pure Elixir reference backend for development and testing, and on SuiteSparse:GraphBLAS via Zigler NIFs for native performance in production.

## Features

- **Sparse matrices and vectors** -- COO construction, inspection, element-wise operations
- **12 built-in semirings** -- `plus_times`, `plus_min`, `lor_land`, `min_plus`, and type-specific variants
- **Graph algorithms** -- BFS reachability, BFS levels, SSSP, triangle count, connected components, degree, PageRank
- **Knowledge graph queries** -- `GraphBLAS.Relation` module with multi-predicate traversal and transitive closure
- **Masked operations** -- structural and complement masks on all compute operations
- **Backend selection** -- per-call or application config; structs carry their backend for correct dispatch
- **3 scalar types** -- `:int64`, `:fp64`, `:bool`
- **470 tests**, property-based testing via StreamData

## Architecture

GraphBLAS separates the public API from the computation engine via a backend behaviour:

```
GraphBLAS.Matrix / GraphBLAS.Vector    -- public API (backend-neutral)
GraphBLAS.Backend                      -- behaviour defining the computation contract
GraphBLAS.Backend.Elixir               -- pure Elixir reference implementation
GraphBLAS.Backend.SuiteSparse          -- SuiteSparse:GraphBLAS via Zigler NIFs
```

Each `%Matrix{}` and `%Vector{}` struct carries a `backend` field, so inspection and mutation operations dispatch to the correct backend automatically.

Select a backend via application config:

    config :ex_graphblas, default_backend: GraphBLAS.Backend.Elixir

Or per-call:

    GraphBLAS.Matrix.from_coo(3, 3, entries, :int64, backend: GraphBLAS.Backend.SuiteSparse)

## Quick start

### Sparse matrix operations

    # Create a sparse 3x3 matrix from COO triples
    {:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [
      {0, 1, 1}, {1, 2, 2}, {2, 0, 3}
    ], :int64)

    # Matrix multiplication
    {:ok, result} = GraphBLAS.Matrix.mxm(m, m, :plus_times)

    # Extract entries
    {:ok, entries} = GraphBLAS.Matrix.to_coo(result)

### Graph algorithms

    # Build an adjacency matrix
    {:ok, adj} = GraphBLAS.Matrix.from_coo(5, 5, [
      {0, 1, 1}, {1, 2, 1}, {2, 3, 1}, {3, 4, 1}
    ], :int64)

    # BFS from vertex 0
    {:ok, visited} = GraphBLAS.Algorithm.bfs_reach(adj, 0)

    # Single-source shortest paths
    {:ok, distances} = GraphBLAS.Algorithm.sssp(adj, 0)

    # Triangle count
    {:ok, count} = GraphBLAS.Algorithm.triangle_count(adj)

    # PageRank
    {:ok, ranks} = GraphBLAS.Algorithm.pagerank(adj)

### Knowledge graph queries

    rel = GraphBLAS.Relation.new(100)
    {:ok, rel} = GraphBLAS.Relation.add_triples(rel, :follows, [{0, 1}, {1, 2}, {2, 3}])
    {:ok, rel} = GraphBLAS.Relation.add_triples(rel, :likes, [{1, 3}, {2, 0}])

    # Two-hop traversal: who can X reach by following then liking?
    {:ok, result} = GraphBLAS.Relation.traverse(rel, [:follows, :likes], :lor_land)

    # Transitive closure over :follows
    {:ok, closure} = GraphBLAS.Relation.closure(rel, :follows, :lor_land)

## Built-in semirings

| Name               | Multiply | Add   | Type   | Use                           |
|--------------------|----------|-------|--------|-------------------------------|
| `:plus_times`      | `a * b`  | `a + b` | `:int64` | Standard matrix multiply  |
| `:plus_times_fp64` | `a * b`  | `a + b` | `:fp64`  | Standard matrix multiply  |
| `:plus_min`        | `min(a,b)` | `a + b` | `:int64` | Shortest path           |
| `:plus_min_fp64`   | `min(a,b)` | `a + b` | `:fp64`  | Shortest path           |
| `:min_plus`        | `a + b`  | `min(a,b)` | `:int64` | Shortest path variant  |
| `:min_plus_fp64`   | `a + b`  | `min(a,b)` | `:fp64`  | Shortest path variant  |
| `:max_plus`        | `a + b`  | `max(a,b)` | `:int64` | Longest / critical path |
| `:max_plus_fp64`   | `a + b`  | `max(a,b)` | `:fp64`  | Longest / critical path |
| `:max_min`         | `min(a,b)` | `max(a,b)` | `:int64` | Capacity / bottleneck  |
| `:max_min_fp64`    | `min(a,b)` | `max(a,b)` | `:fp64`  | Capacity / bottleneck  |
| `:lor_land`        | `a and b` | `a or b` | `:bool`  | Boolean adjacency (BFS) |
| `:land_lor`        | `a or b`  | `a and b` | `:bool`  | Dual boolean semiring   |

## Graph algorithms

| Algorithm | Description |
|-----------|-------------|
| `bfs_reach/2` | BFS reachability -- bool vector of visited vertices |
| `bfs_levels/2` | BFS levels -- integer vector of hop distances from source |
| `sssp/2` | Single-source shortest paths (Dijkstra via min-plus semiring) |
| `triangle_count/1` | Undirected triangle count via masked element-wise multiply |
| `connected_components/1` | Connected components via iterative label propagation |
| `degree/2` | In-degree or out-degree vector |
| `pagerank/2` | PageRank with damping factor and convergence check |

All algorithms accept a `backend:` option and work identically on both backends.

## Installation

Add `ex_graphblas` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_graphblas, "~> 0.2.0"}
  ]
end
```

### SuiteSparse backend

To use the native SuiteSparse backend, install SuiteSparse:GraphBLAS and set the include path:

    export SUITESPARSE_INCLUDE_PATH=/opt/homebrew/include/suitesparse

Or in your `config/config.exs`:

    config :ex_graphblas, suitesparse_include_path: "/opt/homebrew/include/suitesparse"

See `guides/installation_guide.md` for platform-specific instructions.

## Status

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Architecture, API, scaffolding | Complete |
| 2 | Pure Elixir reference backend | Complete |
| 3 | SuiteSparse native backend | Complete |
| 4 | Parity and semantic validation | Complete |
| 5 | Masks, descriptors, API honing | Complete |
| 6 | Graph algorithms and knowledge graphs | Complete |
| 7 | Nx integration | Deferred |
| 8 | Hardening, benchmarks, release prep | In progress |

## License

Apache License 2.0. See [LICENSE](LICENSE).
