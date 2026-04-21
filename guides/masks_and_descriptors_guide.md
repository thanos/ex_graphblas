# Masks and Descriptors Guide

**Status: IMPLEMENTED**

## Why masks and descriptors exist

Without masks, every GraphBLAS compute operation writes all computed positions to the result. This is mathematically complete but practically wasteful. Real graph algorithms care about subsets of positions:

- BFS visits unvisited nodes, not all nodes.
- PageRank updates scores for all nodes, but only if they changed.
- Triangle counting intersects adjacency lists, not unions them.

Masks let you restrict which output positions are written. Descriptors let you modify operation semantics (transpose inputs, replace output) without creating new operation variants.

## Using masks

### Structural mask

A structural mask writes only at positions where the mask has stored entries:

```elixir
alias GraphBLAS.{Matrix, Mask}

# Create a result matrix with entries at many positions
{:ok, a} = Matrix.from_coo(3, 3, [{0, 0, 1}, {0, 1, 2}, {1, 1, 3}, {2, 2, 4}], :int64)
{:ok, b} = Matrix.from_coo(3, 3, [{0, 0, 5}, {1, 0, 6}, {2, 1, 7}], :int64)

# Create a mask that only allows writing to the diagonal
{:ok, mask_m} = Matrix.from_coo(3, 3, [{0, 0, 1}, {1, 1, 1}, {2, 2, 1}], :bool)
mask = Mask.new(mask_m)

# mxm result is masked — only diagonal entries survive
{:ok, c} = Matrix.mxm(a, b, :plus_times, mask: mask)
```

The mask's values are ignored in structural mode. Only its structure (which positions have entries) matters.

### Complement mask

A complement mask writes only at positions where the mask does NOT have stored entries:

```elixir
# "visited" vector marks nodes 0 and 1 as visited
{:ok, visited} = Vector.from_entries(4, [{0, true}, {1, true}], :bool)

# Compute neighbors, but only keep unvisited ones
{:ok, neighbors} = Vector.vxm(frontier, adjacency, :lor_land,
  mask: Mask.complement(visited)
)
```

Complement masks are the primary mechanism for BFS-style "only process new things" patterns.

### Mask type rules

The mask type must match the output type:

| Operation | Output type | Mask type |
|-----------|-------------|-----------|
| `matrix_mxm` | Matrix | Matrix |
| `matrix_mxv` | Vector | Vector |
| `matrix_ewise_add` | Matrix | Matrix |
| `matrix_ewise_mult` | Matrix | Matrix |
| `matrix_reduce` | Vector | Vector |
| `matrix_transpose` | Matrix | Matrix |
| `vector_vxm` | Vector | Vector |
| `vector_ewise_add` | Vector | Vector |
| `vector_ewise_mult` | Vector | Vector |

A type mismatch returns `{:error, {:mask_type_mismatch, ...}}`.

## Using descriptors

### Transpose input descriptors

The most common descriptor use is transposing inputs without copying:

```elixir
alias GraphBLAS.{Matrix, Descriptor}

# Without descriptor: must explicitly transpose (creates a copy)
{:ok, at} = Matrix.transpose(a)
{:ok, c} = Matrix.mxm(at, b, :plus_times)

# With descriptor: no copy needed
{:ok, c} = Matrix.mxm(a, b, :plus_times, descriptor: Descriptor.inp0_transpose())
```

The second form is more efficient (no intermediate matrix) and more readable (intent is explicit).

### Combining masks and descriptors

Masks and descriptors compose naturally:

```elixir
# Compute A^T * B, writing only to positions not in the visited mask
{:ok, c} = Matrix.mxm(a, b, :plus_times,
  mask: Mask.complement(visited),
  descriptor: Descriptor.new(inp0_transpose: :transpose)
)
```

### Replace output descriptor

The `output: :replace` descriptor clears the output before writing. In the current API (which always creates fresh results), it is a no-op. It becomes meaningful when in-place operations are added:

```elixir
# Future: in-place mxm that replaces the contents of c
# {:ok, c} = Matrix.mxm_into(c, a, b, :plus_times, descriptor: Descriptor.replace_output())
```

For now, use `Descriptor.replace_output()` to prepare for in-place operations.

## Container manipulation

### Setting entries

Write a value at a specific position:

```elixir
{:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 1}], :int64)

# Add an entry at (1, 2)
{:ok, m} = Matrix.set(m, 1, 2, 5)

# Overwrite an existing entry at (0, 0)
{:ok, m} = Matrix.set(m, 0, 0, 10)
```

`set` always overwrites. It does not combine with the existing value.

### Extracting entries

Read a value at a specific position:

```elixir
{:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 42}], :int64)

{:ok, 42} = Matrix.extract(m, 0, 0)   # stored entry
{:ok, 0}  = Matrix.extract(m, 1, 1)   # structural zero returns default
```

For structural zeros, `extract` returns the default value for the type (0 for :int64, 0.0 for :fp64, false for :bool).

### Duplicating containers

Deep-copy a container. The copy is independent — modifying it does not affect the original:

```elixir
{:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 1}, {1, 1, 2}], :int64)
{:ok, copy} = Matrix.dup(m)

# Modifying copy does not affect m
{:ok, copy} = Matrix.set(copy, 0, 0, 99)
{:ok, 1} = Matrix.extract(m, 0, 0)    # original unchanged
{:ok, 99} = Matrix.extract(copy, 0, 0) # copy modified
```

## How masks are implemented

### Elixir reference backend

The reference backend computes the full result, then filters:

1. Compute the result as usual.
2. Get the mask's structural positions from its `:data` map (the keys).
3. For structural mask: keep result entries whose position is in the mask positions.
4. For complement mask: keep result entries whose position is NOT in the mask positions.

### SuiteSparse native backend

The native backend passes the mask pointer directly to the C function:

1. Extract the mask container's C pointer from its `:data` field (`data[:ptr]`).
2. Pass it as the `Mask` parameter to the SuiteSparse function.
3. If complement mask, set `GrB_MASK_COMP` on the descriptor.
4. If structural mask (default), set `GrB_STRUCTURE` on the MASK field of the descriptor.
5. SuiteSparse applies the mask internally (possibly with optimization).

The SuiteSparse backend defaults to "valued" mask mode (uses mask values), while the Elixir backend defaults to "structural" (uses positions). When a mask is provided without an explicit descriptor, the SuiteSparse backend sets `mask_structural = true` to match the Elixir backend's default.

## How descriptors are implemented

### Elixir reference backend

The reference backend interprets descriptor fields in Elixir:

- `inp0_transpose: :transpose` → call `matrix_transpose` on first input
- `inp1_transpose: :transpose` → call `matrix_transpose` on second input
- `output: :replace` → no-op (always creates fresh result)
- `mask: :value` → filter mask entries by their values (nonzero/true = mask position)

### SuiteSparse native backend

The native backend creates a `GrB_Descriptor` object:

1. Resolve descriptor flags from the `Descriptor` struct and mask options.
2. Map flags to a pre-defined descriptor global (e.g., `GrB_DESC_SC` for structural complement mask) when available.
3. For uncommon combinations, create a custom descriptor via `descriptor_create` NIF.
4. Pass the descriptor to the compute function.
5. After the NIF call, free only custom descriptors (pre-defined globals must NOT be freed).

Transposition is handled on the Elixir side (not via SuiteSparse descriptor `GrB_INP0_TRAN`) to avoid dimension mismatches with the pre-created result matrix. The `maybe_transpose_inp0/inp1` helpers call `matrix_transpose` before passing to the NIF.

## Memory management with masks

Masks reference existing containers. They do NOT take ownership:

```elixir
# After using a mask, the mask container still needs to be freed
# (for SuiteSparse backend)
SuiteSparse.matrix_free(mask_matrix)
```

The mask container must outlive the compute operation. Do not free the mask before using it.
