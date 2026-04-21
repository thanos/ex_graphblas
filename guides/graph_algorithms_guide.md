# Graph Algorithms and Knowledge Graphs Guide

**Status: IMPLEMENTED**

## Using graph algorithms

All algorithms are in `GraphBLAS.Algorithm` and accept the adjacency matrix convention: `A[i][j]` means edge FROM vertex i TO vertex j.

### BFS reachability

Find all vertices reachable from a source:

```elixir
alias GraphBLAS.{Matrix, Algorithm}

{:ok, adj} = Matrix.from_coo(5, 5, [{0, 1, true}, {1, 2, true}, {2, 3, true}, {3, 4, true}], :bool)
{:ok, visited} = Algorithm.bfs_reach(adj, 0)
# visited: true at indices 0, 1, 2, 3, 4
```

### BFS with levels

Find hop distances from a source:

```elixir
{:ok, levels} = Algorithm.bfs_levels(adj, 0)
# levels: 0 at index 0, 1 at index 1, 2 at index 2, etc.
```

### Shortest path

Find minimum-weight distances from a source (fp64 only):

```elixir
{:ok, weighted} = Matrix.from_coo(4, 4, [{0, 1, 2.0}, {1, 2, 3.0}, {0, 2, 10.0}], :fp64)
{:ok, dist} = Algorithm.sssp(weighted, 0)
# dist[1] = 2.0, dist[2] = 5.0 (0→1→2 is shorter than 0→2)
```

### Triangle counting

Count triangles in an undirected graph (symmetric adjacency):

```elixir
# K4: 4 vertices, all connected = 4 triangles
{:ok, k4} = Matrix.from_coo(4, 4, [
  {0, 1, true}, {1, 0, true}, {0, 2, true}, {2, 0, true},
  {0, 3, true}, {3, 0, true}, {1, 2, true}, {2, 1, true},
  {1, 3, true}, {3, 1, true}, {2, 3, true}, {3, 2, true}
], :bool)
{:ok, 4} = Algorithm.triangle_count(k4)
```

### Connected components

Assign component IDs to vertices:

```elixir
{:ok, components} = Algorithm.connected_components(adj)
# All vertices in the same component share the same ID
```

### PageRank

Compute importance scores:

```elixir
{:ok, ranks} = Algorithm.pagerank(adj, damping: 0.85, max_iter: 100, tol: 1.0e-6)
```

### Degree

Compute in-degree and out-degree:

```elixir
{:ok, %{in_degree: ind, out_degree: outd}} = Algorithm.degree(adj)
```

## Using knowledge graph operations

### Building a relation

```elixir
alias GraphBLAS.Relation

# 4 entities: alice=0, bob=1, carol=2, dave=3
rel = Relation.new(4)

{:ok, rel} = Relation.add_triples(rel, :follows, [{0, 1}, {1, 2}])  # alice follows bob, bob follows carol
{:ok, rel} = Relation.add_triples(rel, :likes, [{0, 2}, {1, 2}])    # alice likes carol, bob likes carol
{:ok, rel} = Relation.add_triples(rel, :knows, [{0, 1}, {1, 0}])    # alice knows bob, bob knows alice
```

### Multi-hop traversal

"Who does Alice follow-then-like?"

```elixir
{:ok, result} = Relation.traverse(rel, [:follows, :likes], :lor_land)
# result[0][2] = true (alice→bob→carol: follows then likes)
```

"Are there any follows-then-likes paths?"

```elixir
{:ok, result} = Relation.traverse(rel, [:follows, :likes], :lor_land)
```

"How many follows-then-likes paths exist between each pair?"

```elixir
{:ok, result} = Relation.traverse(rel, [:follows, :likes], :plus_times)
```

### Transitive closure

"Who can each person eventually reach by following?"

```elixir
{:ok, reachable} = Relation.closure(rel, :follows, :lor_land)
# alice can reach bob (direct) and carol (via bob)
```

"What is the shortest following-path between each pair?"

```elixir
{:ok, shortest} = Relation.closure(rel, :follows, :plus_min)
```

## Using fixed-point iteration

The `fixed_point` primitive iterates a step function until convergence:

```elixir
alias GraphBLAS.Algorithm

# Transitive closure of an edge matrix
{:ok, closure, info} = Algorithm.fixed_point(
  edges,
  fn p ->
    {:ok, new_paths} = GraphBLAS.Matrix.mxm(p, edges, :lor_land)
    GraphBLAS.Matrix.ewise_add(edges, new_paths, :lor)
  end,
  max_iter: 50
)
# info = %{iterations: 3, converged: true}
```

Different semirings answer different queries with the same iteration:

```elixir
# Reachability
Algorithm.fixed_point(edges, fn p ->
  GraphBLAS.Matrix.ewise_add(edges, GraphBLAS.Matrix.mxm(p, edges, :lor_land), :lor)
end, [])

# Shortest path
Algorithm.fixed_point(edges, fn p ->
  GraphBLAS.Matrix.ewise_add(edges, GraphBLAS.Matrix.mxm(p, edges, :plus_min_fp64), :min_fp64)
end, [])

# Path counting
Algorithm.fixed_point(edges, fn p ->
  GraphBLAS.Matrix.ewise_add(edges, GraphBLAS.Matrix.mxm(p, edges, :plus_times), :plus)
end, [])
```

## How algorithms map to matrix operations

| Algorithm | Core operation | Semiring | Mask usage |
|-----------|---------------|----------|------------|
| BFS reach | `vxm` | `lor_land` | Complement mask prevents revisits |
| BFS levels | `vxm` | `lor_land` + Elixir stamping | Complement mask + structural mask |
| SSSP | `vxm` | `plus_min_fp64` | None (full relaxation) |
| Triangle count | `mxm` | `plus_times` | Structural mask on lower triangle |
| Connected comp | `vxm` + `ewise_add` | `lor_land` + `plus_min` | Complement mask per component |
| Degree | `reduce` | `plus` (monoid) | None |
| PageRank | `mxv` | `plus_times_fp64` | None |

## How knowledge graph queries map to matrix operations

| Query | Operation | Semiring |
|-------|-----------|----------|
| Does path exist? | `mxm` chain | `lor_land` |
| How many paths? | `mxm` chain | `plus_times` |
| Shortest path? | `mxm` chain | `plus_min` |
| Widest path? | `mxm` chain | `max_min` |
| Can reach eventually? | Fixed-point `mxm` | `lor_land` |
| Shortest eventual path? | Fixed-point `mxm` | `plus_min` |

## Memory management

Algorithm functions manage intermediate containers internally. On the SuiteSparse backend, intermediate matrices and vectors created during iteration are freed within the algorithm loop. Users receive only the final result.

For the Elixir reference backend, no manual memory management is needed.
