# GraphBLAS

An Elixir library for sparse linear algebra and graph computation, inspired by the GraphBLAS standard.

[![Hex.pm](https://img.shields.io/hexpm/v/ex_graphblas.svg)](https://hex.pm/packages/ex_graphblas)
[![Hex.pm](https://img.shields.io/hexpm/dt/ex_graphblas.svg)](https://hex.pm/packages/ex_graphblas)
[![Hex.pm](https://img.shields.io/hexpm/l/ex_graphblas.svg)](https://hex.pm/packages/ex_graphblas)
[![HexDocs.pm](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_graphblas)


GraphBLAS provides idiomatic Elixir data structures at the boundary while delegating computation to swappable backends. The same code runs on a pure Elixir reference backend for development and testing, and on SuiteSparse:GraphBLAS via Zigler NIFs for native performance in production.

## Contents

- [Features](#features)
- [Architecture](#architecture)
- [Quick start](#quick-start)
- [Use cases](#use-cases)
- [Built-in semirings](#built-in-semirings)
- [Graph algorithms](#graph-algorithms)
- [Installation](#installation)
- [Guides](#guides)
- [Status](#status)
- [License](#license)

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

## Use cases

This section sketches a few concrete scenarios and how to approach them with GraphBLAS. The guides go deeper; here we focus on the high-level shape of a solution.

### 1. Social graph: two-hop follower recommendations

Goal: “Suggest accounts I might want to follow based on people my friends follow.”

1. Model your social graph as an adjacency matrix `A` where `A[i,j] == 1` when user `i` follows `j`.
2. Compute `A * A` using a boolean semiring to capture two-hop reachability.

```elixir
alias GraphBLAS.{Matrix, Algorithm}

# 0 follows 1, 1 follows 2
{:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 1}], :int64)
{:ok, reach2} = Matrix.mxm(adj, adj, :lor_land)

# reach2[0,2] is true: "0 can reach 2 in two hops"
```

Interpretation: non-zero entries in row `i` of `reach2` are candidates for “people you may know” based on two-hop paths. You can mask out already-followed accounts with a mask matrix (see the masks and descriptors guide).

### 2. Weighted shortest paths in logistics or routing

Goal: “Compute the cheapest cost from a depot to every destination.”

1. Model edges as weights (cost, time, distance) in a weighted adjacency matrix.
2. Use `GraphBLAS.Algorithm.sssp/2` which builds on the min-plus semiring.

```elixir
alias GraphBLAS.{Matrix, Algorithm}

{:ok, weighted} = Matrix.from_coo(4, 4, [
  {0, 1, 2.0},
  {1, 2, 3.0},
  {0, 2, 10.0}
], :fp64)

{:ok, dist} = Algorithm.sssp(weighted, 0)
# dist[1] = 2.0, dist[2] = 5.0 (0→1→2 is cheaper than 0→2)
```

This pattern generalises to road networks, communication networks, and any place where “cheapest path” matters.

### 3. Knowledge graph traversal and path queries

Goal: “Answer multi-hop questions over typed relationships.”

1. Store triples `(subject, predicate, object)` in `GraphBLAS.Relation`.
2. Use `Relation.traverse/3` to describe a path of predicates.

```elixir
alias GraphBLAS.Relation

# alice=0, bob=1, carol=2, dave=3
rel = Relation.new(4)
{:ok, rel} = Relation.add_triples(rel, :follows, [{0, 1}, {1, 2}])
{:ok, rel} = Relation.add_triples(rel, :likes, [{1, 2}])

{:ok, result} = Relation.traverse(rel, [:follows, :likes], :lor_land)
# result[0,2] == true means:
#   "there exists x such that 0 --follows→ x --likes→ 2"
```

This pattern scales to more complex path expressions and aggregation semirings (e.g. counting paths with `:plus_times`).

For a deeper, tutorial-style treatment of these examples, see the guides listed below.

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

## Guides

The guides in the `guides/` directory provide end-to-end walkthroughs:

- `guides/installation_guide.md` – installing ex_graphblas and SuiteSparse.
- `guides/architecture_walkthrough.md` – how the library is structured and why.
- `guides/reference_backend_walkthrough.md` – the pure Elixir backend and data model.
- `guides/native_backend_walkthrough.md` – the SuiteSparse backend and NIF boundary.
- `guides/graph_algorithms_guide.md` – graph algorithms and knowledge graph operations.
- `guides/masks_and_descriptors_guide.md` – controlling computation with masks and descriptors.
- `guides/parity_testing_guide.md` – keeping backends in sync with property tests.

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

### Roadmap & milestones

These are not hard promises, but they capture the intended evolution of the library:

- **Milestone: 0.2.x – Native backend + CI hardening (current)**  
  - Ship a robust SuiteSparse backend behind `GraphBLAS.Backend.SuiteSparse`.
  - Provide precompiled NIFs for common platforms, with CI-tested source builds as a fallback.
  - Stabilise dialyzer, lint, and precompiled-NIF workflows.

- **Milestone: 0.3.x – Developer experience and observability**  
  - Improve error messages from the native backend, with clearer reasons and actionable hints.  
  - Add instrumentation hooks so long-running operations can be measured (timers, counters) without exposing backend internals.

- **Milestone: 0.4.x – Higher-level graph APIs**  
  - Add richer graph helpers (graph builders, canned patterns) on top of the existing primitive operations.  
  - Extend the `GraphBLAS.Relation` API with more path-query combinators and convenience functions.

- **Milestone: 0.5.x – Nx and ecosystem integration (Phase 7)**  
  - Revisit Nx integration once the core library is stable, focusing on zero-copy interop where possible.  
  - Explore bridges to popular Elixir data tooling (e.g. Explorer, Livebook examples) using GraphBLAS under the hood.

## License

Apache License 2.0. See [LICENSE](LICENSE).
