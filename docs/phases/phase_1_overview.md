# Phase 1 Overview: Architecture, API Shape, and Scaffolding

## What was built

Phase 1 establishes the complete architectural skeleton for GraphBLAS. It is a reviewable, strategically correct foundation for all future phases.

### Modules delivered

| Module | Purpose |
|--------|---------|
| `GraphBLAS` | Top-level API entry point; delegates config and provides library info |
| `GraphBLAS.Types` | Shared type definitions (scalar_type, shape, index, coo_entry, etc.) |
| `GraphBLAS.Error` | Structured error types with category atoms and human-readable formatting |
| `GraphBLAS.Config` | Backend resolution and configuration access |
| `GraphBLAS.Backend` | Behaviour defining the full computation contract for backends |
| `GraphBLAS.Backend.Elixir` | Pure Elixir reference implementation (correct, not performant) |
| `GraphBLAS.Backend.SuiteSparse` | Placeholder returning `{:error, {:unsupported_operation, ...}}` |
| `GraphBLAS.Matrix` | Public API for sparse matrix operations |
| `GraphBLAS.Vector` | Public API for sparse vector operations |
| `GraphBLAS.Scalar` | Typed scalar wrapper (pairs value with type) |
| `GraphBLAS.Semiring` | Semiring definitions (plus_times, plus_min, max_plus, lor_land, etc.) |
| `GraphBLAS.Monoid` | Monoid definitions (plus, times, min, max, land, lor, lxor) |
| `GraphBLAS.BinaryOp` | Binary operator definitions and application |
| `GraphBLAS.UnaryOp` | Unary operator definitions and application |
| `GraphBLAS.Mask` | Mask type definition (structural and complement) |
| `GraphBLAS.Descriptor` | Operation modifier definition (transpose, replace, mask mode) |

### Configuration system

```elixir
# config/config.exs
config :ex_graphblas, default_backend: GraphBLAS.Backend.Reference

# Per-call override
GraphBLAS.Matrix.from_coo(3, 3, entries, :int64, backend: MyBackend)
```

### Test suite

107 tests covering:
- Type validation and inference
- Error construction, formatting, and raising
- Configuration and backend resolution
- All Reference backend operations (matrix creation, COO import, mxm, mxv, ewise, reduce, transpose)
- All Reference backend vector operations (creation, entries, vxm, ewise, reduce)
- Scalar construction and zero/identity
- Semiring and monoid built-in resolution
- BinaryOp and UnaryOp application
- Mask and Descriptor construction
- SuiteSparse placeholder returning unsupported errors
- Top-level API (default_backend, info)

## What was intentionally deferred

| Capability | Planned phase | Reason |
|---|---|---|
| Phase 2 (done)     Pure Elixir reference backend — semantic oracle, flat maps
| Phase 3            SuiteSparse native backend — performance
| Masked operations (applying masks to computation) | Phase 4 | Descriptors and masks defined; execution deferred |
| Full descriptor control | Phase 4 | Type defined; all modifiers not yet wired |
| Graph algorithms (BFS, PageRank, etc.) | Phase 5 | Requires operations from Phase 3 |
| Nx integration | Phase 6 | Must not distort core design |
| Benchmarks and hardening | Phase 7 | Premature before operations are complete |

## Architecture: the three-layer design

```
+-------------------------------------------+
|            Public API Layer                |
|  Matrix  Vector  Semiring  Monoid  Mask   |
|  Scalar  BinaryOp  UnaryOp  Descriptor    |
+-------------------------------------------+
                    |
                    | delegates via Config.resolve_backend/1
                    v
+-------------------------------------------+
|          Backend Behaviour                 |
|  GraphBLAS.Backend (callbacks)           |
+-------------------------------------------+
                    |
          +---------+---------+
          |                   |
          v                   v
+------------------+  +------------------+
| Reference        |  | SuiteSparse      |
| (pure Elixir)    |  | (Phase 2: NIF)   |
+------------------+  +------------------+
```

### Public API layer

The public API modules (`Matrix`, `Vector`, etc.) contain:
- Struct definitions with typed fields (`shape`, `type`, `data`)
- Delegating functions that resolve the backend and call `backend.callback(...)`
- Zero business logic themselves

This means adding a new backend requires implementing one module, not touching the public API.

### Backend behaviour

`GraphBLAS.Backend` defines 24 callbacks covering all matrix and vector operations. Each callback returns `{:ok, result}` or `{:error, %Error{}}`. The behaviour is:
- Stateless: backends are modules, not processes
- Side-effect-free at the Elixir layer (native backends may have side effects in NIFs)
- Async-ready: no state coupling between calls

### Opaque data convention

The `:data` field in `Matrix` and `Vector` structs is **opaque**. The Reference backend stores Elixir maps; the SuiteSparse backend will store NIF resource references. Calling code must never pattern-match on `:data`. This is the critical boundary that makes backend swapping safe.

## How backend selection works

1. **Application config**: `config :ex_graphblas, default_backend: GraphBLAS.Backend.Elixir`
2. **`GraphBLAS.Config.default_backend/0`**: Reads config, falls back to `GraphBLAS.Backend.Elixir`
3. **`GraphBLAS.Config.resolve_backend/1`**: Takes an optional keyword list; extracts `:backend` key or falls back to default
4. **Public API functions**: Call `Config.resolve_backend(opts)` to get the backend module, then dispatch

This three-step resolution allows:
- Global default via config
- Per-call override without touching global state
- Testing with mock backends without modifying application config
