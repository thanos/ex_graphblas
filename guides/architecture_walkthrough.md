# Architecture Walkthrough: GraphBLAS for the Elixir Engineer

## The problem GraphBLAS solves

Suppose you have a social network with 10 million users. Each user follows a few hundred others. You want to find all users reachable within two hops from user 42.

The adjacency matrix is 10 million by 10 million. Storing it densely requires 100 trillion entries. But only about 1 billion entries are non-zero (each user follows ~100 others). That is 99.99% sparsity.

A sparse matrix stores only the 1 billion non-zeros. A sparse semiring multiplication operates only on stored entries, skipping the 99.99% that are zero. This turns a computationally intractable problem into one that finishes in seconds.

GraphBLAS provides the Elixir API for this kind of computation.

## Creating your first sparse matrix

```elixir
# A 4-node directed cycle: 0 -> 1 -> 2 -> 3 -> 0
{:ok, adj} = GraphBLAS.Matrix.from_coo(4, 4, [
  {0, 1, 1},
  {1, 2, 1},
  {2, 3, 1},
  {3, 0, 1}
], :int64)
```

The arguments are:
1. Number of rows (4)
2. Number of columns (4)
3. A list of `{row, col, value}` triples (COO format)
4. The scalar type (`:int64` for integers)

This creates a sparse matrix with exactly 4 stored entries. The other 12 entries are implicitly zero.

```elixir
{:ok, {4, 4}} = GraphBLAS.Matrix.shape(adj)   # dimensions
{:ok, 4} = GraphBLAS.Matrix.nvals(adj)          # stored entries
{:ok, :int64} = GraphBLAS.Matrix.type(adj)      # scalar type
```

## Inspecting a matrix

```elixir
{:ok, entries} = GraphBLAS.Matrix.to_coo(adj)
# [{0, 1, 1}, {1, 2, 1}, {2, 3, 1}, {3, 0, 1}]
```

Entries are returned in row-major order (sorted by row, then column). This is the canonical form for comparison.

## Matrix multiplication: the heart of GraphBLAS

### Standard multiplication

```elixir
# adj * adj gives two-hop reachability
{:ok, reach2} = GraphBLAS.Matrix.mxm(adj, adj, :plus_times)
```

What happens internally:
1. For each pair `(i, j)`, compute `C[i,j] = sum(A[i,k] * B[k,j])` for all k where both A and B have stored entries
2. In our case, `adj * adj` connects nodes that are two hops apart
3. The `:plus_times` semiring tells us: multiply matching entries with `*`, combine using `+`

### Changing the semiring changes the algorithm

```elixir
# Boolean reachability (two hops, ignoring edge weights)
{:ok, bool_reach2} = GraphBLAS.Matrix.mxm(adj, adj, :lor_land)

# Shortest path (two edges, minimum total weight)
{:ok, shortest2} = GraphBLAS.Matrix.mxm(weighted_adj, weighted_adj, :plus_min)
```

The same `mxm` operation, different semiring, different algorithm. This is the core power of GraphBLAS.

## Vectors: the one-dimensional sibling

```elixir
# A vector representing "start from node 0"
{:ok, start} = GraphBLAS.Vector.from_entries(4, [{0, 1}], :int64)

# One hop: which nodes are reachable from node 0?
{:ok, reachable} = GraphBLAS.Matrix.mxv(adj, start, :lor_land)

# The result tells us: node 1 is reachable from node 0
{:ok, entries} = GraphBLAS.Vector.to_entries(reachable)
# [{1, 1}]
```

`mxv` multiplies a matrix by a vector. `vxm` multiplies a vector by a matrix (from the left). Both use the same semiring mechanism.

## Element-wise operations

### ewise_add: union of positions

```elixir
{:ok, union} = GraphBLAS.Matrix.ewise_add(adj, adj, :plus)
# Positions that exist in EITHER matrix appear in the result
# Overlapping positions are combined using the monoid (+: sum the values)
```

### ewise_mult: intersection of positions

```elixir
{:ok, intersection} = GraphBLAS.Matrix.ewise_mult(adj, adj, :times)
# Only positions that exist in BOTH matrices appear in the result
# Values are combined using the monoid (*: multiply the values)
```

The mnemonic: `ewise_add` is like set union, `ewise_mult` is like set intersection.

## Reduction

```elixir
# Sum all values in each row
{:ok, row_sums} = GraphBLAS.Matrix.reduce(adj, :plus)

# Sum all values in a vector
{:ok, total} = GraphBLAS.Vector.reduce(start, :plus)
GraphBLAS.Scalar.value(total)  # => 1
```

Reduction collapses a dimension using a monoid. For matrices, it reduces each row to a scalar, producing a vector. For vectors, it reduces all values to a single scalar.

## Transpose

```elixir
{:ok, t} = GraphBLAS.Matrix.transpose(adj)
# The transpose swaps rows and columns: A[i,j] becomes A^T[j,i]
# For our directed cycle: 0->1 becomes 1->0 (reversed edges)
```

## How backend selection works

Every operation resolves its backend before executing:

```elixir
# Inside GraphBLAS.Matrix.mxm/4:
def mxm(%Matrix{} = a, %Matrix{} = b, semiring \\ :plus_times, opts \\ []) do
  backend = Config.resolve_backend(opts)  # 1. Check opts for :backend key
  backend.matrix_mxm(a, b, semiring, opts) # 2. Delegate to backend
end
```

The backend resolution chain:
1. If `opts` contains `backend: SomeModule`, use that module
2. Otherwise, check `Application.get_env(:ex_graphblas, :default_backend)`
3. Otherwise, fall back to `GraphBLAS.Backend.Elixir`

This means you can:
- Use the default backend globally (via config)
- Override per-call (via options)
- Write tests with mock backends (by passing a test module)

## The backend contract

Every backend must implement `GraphBLAS.Backend`, which defines 24 callbacks:

```elixir
# Matrix callbacks
@callback matrix_new(nrows, ncols, type, opts) :: {:ok, Matrix.t()} | {:error, Error.t()}
@callback matrix_from_coo(nrows, ncols, entries, type, opts) :: ...
@callback matrix_nvals(matrix) :: {:ok, non_neg_integer()} | ...
@callback matrix_mxm(a, b, semiring, opts) :: ...
# ... and so on for all matrix operations

# Vector callbacks
@callback vector_new(size, type, opts) :: ...
@callback vector_from_entries(size, entries, type, opts) :: ...
# ... and so on for all vector operations
```

The Elixir backend implements all 24 callbacks (plus `matrix_to_dense` and `vector_to_list`) using flat tuple-key maps. The SuiteSparse backend (Phase 3) will implement them using NIF calls to the C library.

## Why opaque data?

The `:data` field in Matrix and Vector structs is intentionally opaque:

```elixir
# Elixir backend stores:
%{entries: %{{0, 1} => 1}, nrows: 4, ncols: 4, type: :int64}

# SuiteSparse backend will store:
# A NIF resource reference (an opaque pointer to a GrB_Matrix handle)
```

If calling code pattern-matched on the data field, it would break when switching backends. By keeping data opaque, we guarantee that backend swapping is safe.

**Rule**: Never access the `:data` field directly. Always use API functions.

## Masks and descriptors

Masks and descriptors are fully implemented and supported on all compute operations.

### Masks

```elixir
# A mask restricts which output positions are written
mask = GraphBLAS.Mask.new(frontier)         # write only where frontier has stored entries
cmask = GraphBLAS.Mask.complement(frontier)  # write only where frontier does NOT have stored entries

# Pass as an option to any compute operation
{:ok, result} = GraphBLAS.Matrix.mxm(a, b, :plus_times, mask: mask)
```

### Descriptors

```elixir
# A descriptor modifies how the operation interprets inputs and outputs
desc = GraphBLAS.Descriptor.new(inp0_transpose: :transpose)
# This tells mxm to treat A as if it were transposed, without creating A^T

{:ok, result} = GraphBLAS.Matrix.mxm(a, b, :plus_times, descriptor: desc)
```

See the [Masks and descriptors guide](masks_and_descriptors_guide.md) for full details.

## Completed phases

- **Phase 1**: Core data structures, Backend behaviour, architecture
- **Phase 2**: Elixir reference backend with flat tuple-key maps, semantic correctness tests, dense conversion helpers
- **Phase 3**: SuiteSparse native backend via Zigler, additional semirings, assignment, extraction
- **Phase 4**: Full mask and descriptor support in compute operations
- **Phase 5**: Graph algorithms (BFS, SSSP, triangle count, connected components, PageRank, degree)
- **Phase 6**: Knowledge graph queries (`GraphBLAS.Relation`), transitive closure, fixed-point iteration
