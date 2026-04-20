# Phase 1 Concepts: GraphBLAS for the Elixir Engineer

## Why sparse?

Most real-world data is sparse. A social network with a million users has a million-by-million adjacency matrix, but each user follows maybe a few hundred others. That matrix is 99.99% zeros. Storing it densely wastes nearly all its memory. Computing with it wastes nearly all its FLOPs.

Sparse data structures store only the non-default values (typically the non-zeros). This trades random access speed for massive memory and computation savings. GraphBLAS is designed from the ground up for this trade-off.

## What is GraphBLAS?

GraphBLAS is a mathematical specification, originally developed for graph algorithms expressed as sparse linear algebra. Its key insight:

> Almost every graph algorithm can be expressed as a sequence of sparse matrix operations with the right algebraic structure.

The "right algebraic structure" is a **semiring**, not ordinary arithmetic. By changing which semiring you use, the same matrix multiplication kernel implements:
- Breadth-first search (using the `lor_land` semiring)
- Shortest path (using the `plus_min` semiring)
- Triangle counting (using the `plus_times` semiring on boolean adjacency)

This is why semirings are the central abstraction in GraphBLAS, not a peripheral feature.

## Sparse matrices and vectors

### Matrix construction: COO format

The Coordinate (COO) format stores a matrix as a list of `(row, column, value)` triples. Only non-default entries are listed. For example, the adjacency matrix of a 4-node directed cycle:

```
{0, 1, 1}   -- edge from node 0 to node 1
{1, 2, 1}   -- edge from node 1 to node 2
{2, 3, 1}   -- edge from node 2 to node 3
{3, 0, 1}   -- edge from node 3 to node 0
```

In GraphBLAS:

```elixir
{:ok, m} = GraphBLAS.Matrix.from_coo(4, 4, [
  {0, 1, 1}, {1, 2, 1}, {2, 3, 1}, {3, 0, 1}
], :int64)
```

The first two arguments are the dimensions (4x4). The third is the list of triples. The fourth is the scalar type.

### What does "stored" mean?

A sparse matrix has a declared shape (e.g., 4x4) and a set of "stored" entries. The unstored entries are implicitly the default value (zero for numeric types, false for bool). The number of stored entries (`nvals`) is typically much smaller than the total entries (`nrows * ncols`).

```elixir
{:ok, nvals} = GraphBLAS.Matrix.nvals(m)   # 4, not 16
{:ok, coo} = GraphBLAS.Matrix.to_coo(m)     # [{0,1,1}, {1,2,1}, {2,3,1}, {3,0,1}]
```

### Zero-based indexing

GraphBLAS uses zero-based indexing, matching the GraphBLAS C specification. This differs from Elixir's one-based convention. The choice is deliberate: it avoids index translation at the native boundary and preserves GraphBLAS semantics.

## Semirings

### Mathematical definition

A semiring `(S, multiply, add, add_identity, multiply_identity)` consists of:
- A set S of values
- A multiplicative operator with an identity (like multiplication with identity 1)
- An additive operator with an identity (like addition with identity 0)
- The requirement that multiplication distributes over addition
- The additive identity is an annihilator for multiplication: `a * 0 = 0 * a = 0`

### Why semirings, not just multiplication?

In ordinary matrix multiplication `C = A * B`, entry `C[i,j]` is computed by:
1. For each k where `A[i,k]` and `B[k,j]` are both non-zero, **multiply** `A[i,k] * B[k,j]`
2. **Add** all the products together

The choice of "multiply" and "add" determines what the computation means:

| Semiring | Multiply | Add | Meaning |
|----------|----------|-----|--------|
| `plus_times` | `a * b` | `a + b` | Standard matrix multiplication |
| `plus_min` | `min(a, b)` | `a + b` | Shortest path (edge weights add, pick minimum) |
| `lor_land` | `a and b` | `a or b` | Reachability (BFS on boolean adjacency) |
| `max_plus` | `a + b` | `max(a, b)` | Critical path length |

Same matrix, same operation (`mxm`), different semiring, different algorithm. This is the core insight of GraphBLAS.

### Using semirings in GraphBLAS

```elixir
# Standard multiplication
{:ok, c} = GraphBLAS.Matrix.mxm(a, b, :plus_times)

# Shortest path
{:ok, d} = GraphBLAS.Matrix.mxm(a, b, :plus_min)

# Boolean reachability
{:ok, reachable} = GraphBLAS.Matrix.mxm(adj, adj, :lor_land)
```

Built-in semirings have typed variants (e.g., `:plus_times` for integers, `:plus_times_fp64` for doubles). You can also define custom semirings:

```elixir
{:ok, custom} = GraphBLAS.Matrix.mxm(a, b, GraphBLAS.Semiring.new(
  name: :my_semiring,
  multiply: fn x, y -> x + y end,
  add: fn x, y -> max(x, y) end,
  add_identity: 0,
  multiply_identity: 1,
  type: :int64
))
```

## Monoids

### Definition

A monoid `(S, operator, identity)` is simpler than a semiring:
- An associative binary operator on S (e.g., addition)
- An identity element (e.g., 0 for addition)

Monoids appear in GraphBLAS in three places:
1. **Element-wise addition** (`ewise_add`): combines overlapping entries using the monoid's operator
2. **Reduction** (`reduce`): collapses a vector or matrix to a scalar or smaller vector
3. **COO construction**: resolves duplicate entries (two triples at the same position are combined using the monoid's operator)

### Using monoids

```elixir
# Sum all values in a vector
{:ok, scalar} = GraphBLAS.Vector.reduce(v, :plus)

# Element-wise maximum of two vectors
{:ok, combined} = GraphBLAS.Vector.ewise_add(a, b, :max)
```

## Masks

### What is a mask?

A mask controls which positions in the output of an operation are written to. This is essential for graph algorithms because:
- Adjacency matrices are sparse; computing into all positions is wasteful
- Many algorithms need to write only to "frontier" positions
- Masks avoid creating large intermediate dense matrices

### Structural vs. complement masks

- **Structural mask**: write only where the mask has a stored (non-default) entry
- **Complement mask**: write only where the mask does NOT have a stored entry

In Phase 1, Mask types are defined but not yet wired into operations. Full mask support is planned for Phase 4.

```elixir
mask = GraphBLAS.Mask.new(frontier_matrix)           # structural
cmask = GraphBLAS.Mask.complement(frontier_matrix)    # complement
```

## Descriptors

Descriptors modify how an operation interprets its inputs and writes its output. In GraphBLAS, common descriptors include:
- `inp0_transpose`: treat the first input as transposed
- `inp1_transpose`: treat the second input as transposed
- `output: :replace`: clear the output before writing (vs. `:merge`, which combines)
- `mask: :value`: use the mask's values (vs. `:structural`, which uses only its structure)

Instead of creating `A_transposed` as a separate matrix, you pass `descriptor: GraphBLAS.Descriptor.new(inp0_transpose: :transpose)` to the operation. This avoids a copy and is more memory-efficient.

Phase 1 defines the Descriptor type with sensible defaults. Full wiring comes in Phase 4.

## How the Reference backend computes

The Elixir backend is the authoritative specification for what each operation must produce. Understanding it helps you verify that a future backend (SuiteSparse) is correct.

### Matrix representation

```elixir
%{
  entries: %{{0, 1} => 1, {1, 2} => 1},
  nrows: n,
  ncols: m,
  type: :int64
}
```

Flat tuple-key maps provide single-level lookup. This is intentionally not optimized for large problems — clarity and inspectability are the goals.

### mxm algorithm

```
For each (i, k) in A where A[i,k] is stored:
  For each (j, k) in B where B[k,j] is stored:
    Compute product = multiply(A[i,k], B[k,j])
    Accumulate C[i,j] = add(C[i,j], product)
```

This is standard sparse matrix multiplication. The Reference backend uses `Enum.reduce` and `Map.update` to accumulate results.

### ewise_add vs. ewise_mult

- `ewise_add(a, b, monoid)`: **Union** of positions. Positions in either matrix appear in the result. Overlapping positions are combined with the monoid.
- `ewise_mult(a, b, monoid)`: **Intersection** of positions. Only positions in both matrices appear. Values are combined with the monoid.

This distinction mirrors the set operations: ewise_add is like union, ewise_mult is like intersection.
