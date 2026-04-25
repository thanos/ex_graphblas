# Reference Backend Walkthrough: Understanding GraphBLAS Through Pure Elixir

**Status: IMPLEMENTED**

## The problem we are solving

You have a sparse matrix. Most of its entries are zero. You want to multiply it by another sparse matrix, or add it to another sparse matrix, or reduce it to a vector. You need the result to be correct, and you need to understand what the operation actually computed.

GraphBLAS answers this by defining operations in terms of **semirings**. But before you can appreciate semirings, you need to see what the operations actually do with real numbers in real matrices.

The reference backend is the simplest possible implementation of each operation. It is designed to be read, understood, and verified by hand. If you can read the code and see that `mxm` does what you expect, then you understand GraphBLAS matrix multiplication.

## Your first sparse matrix

```elixir
# A 4-node directed cycle: 0 -> 1 -> 2 -> 3 -> 0
{:ok, adj} = GraphBLAS.Matrix.from_coo(4, 4, [
  {0, 1, 1},
  {1, 2, 1},
  {2, 3, 1},
  {3, 0, 1}
], :int64)
```

This creates a 4x4 matrix where position (0,1)=1, position (1,2)=1, position (2,3)=1, position (3,0)=1, and all other entries are implicitly 0.

The `from_coo` function takes:
1. Number of rows (4)
2. Number of columns (4)
3. A list of `{row, col, value}` triples (COO format)
4. The scalar type (`:int64` for integers)

### What the matrix looks like inside

The Elixir backend stores it as:

```elixir
%{
  entries: %{{0, 1} => 1, {1, 2} => 1, {2, 3} => 1, {3, 0} => 1},
  nrows: 4,
  ncols: 4,
  type: :int64
}
```

This is a flat map with tuple keys. You can inspect it directly:

```elixir
{:ok, 4} = GraphBLAS.Matrix.nvals(adj)         # 4 stored entries
{:ok, {4, 4}} = GraphBLAS.Matrix.shape(adj)    # 4 rows, 4 columns
```

### Inspecting as a dense matrix

For debugging, you can see the whole matrix with zeros filled in:

```elixir
GraphBLAS.Matrix.to_dense(adj)
# => [
#      [0, 1, 0, 0],
#      [0, 0, 1, 0],
#      [0, 0, 0, 1],
#      [1, 0, 0, 0]
#    ]
```

This is the adjacency matrix of a directed cycle graph. Row i, column j is 1 if there is an edge from i to j.

## Multiplication with different semirings

### Standard multiplication: plus_times

```elixir
{:ok, reach2} = GraphBLAS.Matrix.mxm(adj, adj, :plus_times)
GraphBLAS.Matrix.to_dense(reach2)
# => [
#      [0, 0, 1, 0],   # node 0 reaches node 2 in 2 hops
#      [0, 0, 0, 1],   # node 1 reaches node 3 in 2 hops
#      [1, 0, 0, 0],   # node 2 reaches node 0 in 2 hops
#      [0, 1, 0, 0]    # node 3 reaches node 1 in 2 hops
#    ]
```

What happened? The `plus_times` semiring computes:

```
C[i,j] = sum over k: A[i,k] * B[k,j]
```

For each pair (i, j), we find all k where A has an entry at (i,k) and B has an entry at (k,j), multiply the values, and sum the products. With an adjacency matrix (values are all 1), multiplication counts the number of 2-hop paths from i to j.

### Boolean reachability: lor_land

```elixir
{:ok, bool_reach2} = GraphBLAS.Matrix.mxm(adj, adj, :lor_land)
GraphBLAS.Matrix.to_dense(bool_reach2)
# => [
#      [0, 0, 1, 0],
#      [0, 0, 0, 1],
#      [1, 0, 0, 0],
#      [0, 1, 0, 0]
#    ]
```

The `lor_land` semiring (logical OR, logical AND) asks: "Is there ANY path from i to j in exactly 2 hops?" The answer is yes or no (1 or 0). With a boolean adjacency matrix, this gives you 2-hop reachability.

### Shortest path: min_plus

For weighted graphs, the `min_plus` semiring finds the shortest path:

```elixir
# Weighted cycle: edges have different weights
{:ok, weighted} = GraphBLAS.Matrix.from_coo(4, 4, [
  {0, 1, 2},   # edge 0->1 with weight 2
  {1, 2, 3},   # edge 1->2 with weight 3
  {2, 3, 1},   # edge 2->3 with weight 1
  {3, 0, 4}    # edge 3->0 with weight 4
], :int64)

# Two-hop shortest paths
{:ok, sp2} = GraphBLAS.Matrix.mxm(weighted, weighted, :min_plus)
```

The `min_plus` semiring computes:

```
C[i,j] = min over k: A[i,k] + B[k,j]
```

Instead of adding products, it takes the minimum sum. This is the foundation of shortest path algorithms.

**Same `mxm` function. Different semiring. Different algorithm.** This is the core insight of GraphBLAS.

## How mxm works in the reference backend

Let's trace through `plus_times` multiplication of our adjacency matrix with itself:

```
A (adjacency):        B (same as A):
(0,1)=1              (0,1)=1
(1,2)=1              (1,2)=1
(2,3)=1              (2,3)=1
(3,0)=1              (3,0)=1
```

Step 1: For each pair `(i, k)` in A, find if `(k, j)` exists in B:

```
A has (0,1)=1. Does B have (1, j)? Yes: (1,2)=1.
  Product: 1 * 1 = 1.  This contributes to C[0,2].

A has (1,2)=1. Does B have (2, j)? Yes: (2,3)=1.
  Product: 1 * 1 = 1.  This contributes to C[1,3].

A has (2,3)=1. Does B have (3, j)? Yes: (3,0)=1.
  Product: 1 * 1 = 1.  This contributes to C[2,0].

A has (3,0)=1. Does B have (0, j)? Yes: (0,1)=1.
  Product: 1 * 1 = 1.  This contributes to C[3,1].
```

Step 2: Combine products at the same position using addition:

```
C[0,2] = 1 (only one product, nothing to add)
C[1,3] = 1
C[2,0] = 1
C[3,1] = 1
```

Result: `C = {(0,2): 1, (1,3): 1, (2,0): 1, (3,1): 1}`

This is exactly what you get from `GraphBLAS.Matrix.mxm(adj, adj, :plus_times)`.

## Element-wise operations

### ewise_add: set union

```elixir
{:ok, a} = GraphBLAS.Matrix.from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64)
{:ok, b} = GraphBLAS.Matrix.from_coo(2, 2, [{0, 0, 3}, {0, 1, 4}], :int64)

{:ok, c} = GraphBLAS.Matrix.ewise_add(a, b, :plus)
GraphBLAS.Matrix.to_dense(c)
# => [[4, 4],   # (0,0): 1+3=4, (0,1): 0+4=4
#     [0, 2]]   # (1,0): neither, (1,1): 2+0=2
```

`ewise_add` takes the **union** of structural positions. Where both matrices have an entry, the values are combined using the monoid (here: addition). Where only one has an entry, that value is kept.

### ewise_mult: set intersection

```elixir
{:ok, a} = GraphBLAS.Matrix.from_coo(2, 2, [{0, 0, 2}, {0, 1, 3}], :int64)
{:ok, b} = GraphBLAS.Matrix.from_coo(2, 2, [{0, 0, 4}, {1, 0, 5}], :int64)

{:ok, c} = GraphBLAS.Matrix.ewise_mult(a, b, :times)
GraphBLAS.Matrix.to_dense(c)
# => [[8, 0],   # (0,0): 2*4=8, (0,1): not in both => 0
#     [0, 0]]   # (1,0): not in both => 0, (1,1): not in both => 0
```

`ewise_mult` takes the **intersection** of structural positions. Only positions present in both matrices appear in the result.

## Reduction

```elixir
{:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 0, 1}, {0, 1, 2}, {2, 0, 5}], :int64)
{:ok, row_sums} = GraphBLAS.Matrix.reduce(m, :plus)
GraphBLAS.Vector.to_list(row_sums)
# => [3, 0, 5]   # row 0: 1+2=3, row 1: empty=0, row 2: 5
```

`reduce` collapses each row (or column, with a descriptor) to a single value using the monoid.

## Transpose

```elixir
{:ok, m} = GraphBLAS.Matrix.from_coo(2, 3, [{0, 2, 7}, {1, 0, 3}], :int64)
{:ok, t} = GraphBLAS.Matrix.transpose(m)
GraphBLAS.Matrix.to_dense(t)
# => [[0, 3],   # was column 0: (1,0)=3 -> (0,1)=3
#     [0, 0],
#     [7, 0]]   # was column 2: (0,2)=7 -> (2,0)=7
```

## How the backend resolution works

Every API function resolves its backend before dispatching:

```elixir
def mxm(%Matrix{} = a, %Matrix{} = b, semiring \\ :plus_times, opts \\ []) do
  backend = GraphBLAS.Config.resolve_backend(opts)
  backend.matrix_mxm(a, b, semiring, opts)
end
```

This means:
1. By default, operations use `GraphBLAS.Backend.Elixir` (from config)
2. You can override per-call: `Matrix.mxm(a, b, :plus_times, backend: MyBackend)`
3. Adding a new backend (SuiteSparse, port-based) requires only implementing the behaviour

## Why this matters for the future

When the SuiteSparse backend arrives in Phase 3, we will run the exact same tests against it:

```elixir
# Phase 4 parity test (conceptual)
ref_result = Matrix.mxm(a, b, :plus_times, backend: GraphBLAS.Backend.Elixir)
nat_result = Matrix.mxm(a, b, :plus_times, backend: GraphBLAS.Backend.SuiteSparse)
assert results_equal?(ref_result, nat_result)
```

If the native backend ever disagrees with the reference backend, the reference backend is right by definition. This is why the reference backend must be simple, clear, and obviously correct.

## Next steps

After reading this walkthrough, you should be able to:

1. Create a sparse matrix from COO triples
2. Multiply matrices using different semirings
3. Understand what the result means (reachability, shortest path, etc.)
4. Inspect matrix contents using `to_dense`
5. Explain why the reference backend uses flat maps instead of nested structures
6. Follow the code in `GraphBLAS.Backend.Elixir` and verify each operation step by step