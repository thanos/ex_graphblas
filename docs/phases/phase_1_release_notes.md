# GraphBLAS Phase 1 Release Notes

## Version 0.1.0 -- Architecture, API Shape, and Scaffolding

This is the first release. It establishes the complete architectural skeleton and a working reference implementation. No native execution is included yet.

### New modules

- **GraphBLAS** -- Top-level entry point. `default_backend/0`, `info/0`.
- **GraphBLAS.Matrix** -- Sparse matrix API. Construction from COO, inspection (shape, type, nvals, to_coo), operations (mxm, mxv, ewise_add, ewise_mult, reduce, transpose).
- **GraphBLAS.Vector** -- Sparse vector API. Construction from entries, inspection (size, type, nvals, to_entries), operations (vxm, ewise_add, ewise_mult, reduce).
- **GraphBLAS.Scalar** -- Typed scalar wrapper. Pairs a value with its GraphBLAS type.
- **GraphBLAS.Semiring** -- Semiring definitions. Built-in: `plus_times`, `plus_times_fp64`, `plus_min`, `plus_min_fp64`, `max_plus`, `max_plus_fp64`, `max_min`, `max_min_fp64`, `lor_land`, `land_lor`. Custom semiring struct creation.
- **GraphBLAS.Monoid** -- Monoid definitions. Built-in: `plus`, `plus_fp32`, `plus_fp64`, `times`, `times_fp32`, `times_fp64`, `min`, `min_fp64`, `max`, `max_fp64`, `land`, `lor`, `lxor`. Custom monoid struct creation.
- **GraphBLAS.BinaryOp** -- Binary operator definitions. Built-in: plus, times, minus, min, max, land, lor, lxor. Custom operator creation.
- **GraphBLAS.UnaryOp** -- Unary operator definitions. Built-in: identity, negate_int, negate_fp, abs_val, l_not. Custom operator creation.
- **GraphBLAS.Mask** -- Mask type definition. Structural and complement masks for future use in operations.
- **GraphBLAS.Descriptor** -- Descriptor type definition. Controls transpose, output mode, and mask semantics for future use.
- **GraphBLAS.Types** -- Shared type specifications (scalar_type, shape, index, coo_entry, vector_entry, opts).
- **GraphBLAS.Error** -- Structured error types. Category-based reasons with human-readable formatting.
- **GraphBLAS.Config** -- Backend configuration and resolution.
- **GraphBLAS.Backend** -- Behaviour defining 24 callbacks for matrix and vector operations.
- **GraphBLAS.Backend.Elixir** -- Pure Elixir reference implementation. Correct but not performant.
- **GraphBLAS.Backend.SuiteSparse** -- Placeholder module. All callbacks return `{:error, {:unsupported_operation, :not_yet_implemented, ...}}`.

### Configuration

Default backend is `GraphBLAS.Backend.Elixir`, configured in `config/config.exs`:

```elixir
config :ex_graphblas, default_backend: GraphBLAS.Backend.Elixir
```

Override per-call:

```elixir
GraphBLAS.Matrix.from_coo(3, 3, entries, :int64, backend: MyBackend)
```

### What you can do now

```elixir
# Create a matrix
{:ok, m} = GraphBLAS.Matrix.from_coo(4, 4, [
  {0, 1, 1}, {1, 2, 1}, {2, 3, 1}, {3, 0, 1}
], :int64)

# Inspect it
{:ok, {4, 4}} = GraphBLAS.Matrix.shape(m)
{:ok, 4} = GraphBLAS.Matrix.nvals(m)
{:ok, :int64} = GraphBLAS.Matrix.type(m)

# Multiply it by itself (reachability)
{:ok, reach2} = GraphBLAS.Matrix.mxm(m, m, :lor_land)

# Create a vector
{:ok, v} = GraphBLAS.Vector.from_entries(4, [{0, 1.0}], :fp64)

# Matrix-vector product
{:ok, result} = GraphBLAS.Matrix.mxv(m, v, :plus_times)

# Reduce a vector to a scalar
{:ok, scalar} = GraphBLAS.Vector.reduce(v, :plus_fp64)
GraphBLAS.Scalar.value(scalar)  # => 1.0

# Transpose a matrix
{:ok, t} = GraphBLAS.Matrix.transpose(m)

# Element-wise operations
{:ok, sum} = GraphBLAS.Matrix.ewise_add(m, m, :plus)
{:ok, prod} = GraphBLAS.Matrix.ewise_mult(m, m, :times)

# Create masks and descriptors (for future use)
mask = GraphBLAS.Mask.new(m)
cmask = GraphBLAS.Mask.complement(m)
desc = GraphBLAS.Descriptor.new(inp0_transpose: :transpose)
```

### What you cannot do yet

- **Native execution**: All computation runs in the Reference backend (pure Elixir). No native/NIF execution yet.
- **Masked operations**: Mask and Descriptor types exist, but they are not wired into the compute operations. Passing masks and descriptors to operations is planned for Phase 4.
- **Graph algorithms**: No BFS, PageRank, or other high-level algorithms yet. These will be built on the operations API in Phase 5.
- **Nx integration**: No conversion to/from Nx tensors. Planned for Phase 6.
- **User-defined operators in native backend**: The Reference backend supports custom functions, but the native backend will require operator registration.

### Known limitations

1. **Elixir backend performance**: The Elixir backend uses flat tuple-key maps. It is correct but slow. Do not benchmark it and draw conclusions about the library's performance ceiling.
2. **COO duplicate resolution**: When creating a matrix from COO triples with duplicate positions, duplicates are combined using the `:plus` monoid by default. This is configurable via the `:combine_monoid` option, but only built-in monoid atoms are currently supported in the Reference backend's constructor.
3. **No mutation**: Matrices and vectors are immutable. There is no `set` or `assign` operation to modify entries in-place. This is intentional: GraphBLAS encourages creating new containers rather than mutating existing ones.
4. **Nx type alignment**: GraphBLAS uses `:fp64` where Nx uses `:f64`. This difference is deliberate (matching GraphBLAS C naming) and will be handled by conversion helpers in Phase 6.

### Design decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Module namespace | `GraphBLAS` (not `Ex`) | `Ex` is too short and collision-prone for Hex |
| Opaque data field | `:data` in structs | Enables backend swapping without API changes |
| Zero-based indexing | Follows GraphBLAS C | Avoids translation errors at the native boundary |
| Custom scalar types | `:int64`, `:fp64`, etc. | Matches GraphBLAS C; distinct from Nx types |
| Error convention | `{:error, %Error{}}` tuples | Structured, pattern-matchable, not exceptions |
| SuiteSparse backend | Placeholder only | Native integration is Phase 2 work |
| Reference backend | Flat tuple-key maps | Correctness first; performance is Phase 7 |

### Test suite

107 tests covering:
- Type validation and inference (Types module)
- Error construction, formatting, and raising (Error module)
- Configuration and backend resolution (Config module)
- Reference backend (now Elixir backend) matrix operations (creation, COO, mxm, mxv, ewise_add, ewise_mult, reduce, transpose)
- Reference backend (now Elixir backend) vector operations (creation, mxv, vxm, ewise_add, ewise_mult, reduce)
- Scalar construction and zero/identity (Scalar module)
- Semiring and monoid built-in resolution and creation
- BinaryOp and UnaryOp application
- Mask and Descriptor construction
- SuiteSparse placeholder returning unsupported errors
- Top-level API (default_backend, info)
