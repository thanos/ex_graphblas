# Phase 1 Review Guide

## What to review before approving Phase 1

This guide lists the specific things a reviewer should verify before accepting Phase 1. Each item includes the rationale for why it matters.

### 1. Architectural invariants

These properties must hold across all files. If any is violated, the architecture is broken.

**Invariant: No direct data access outside backends**

- The `:data` field of `Matrix` and `Vector` structs must never be pattern-matched or directly read outside of `GraphBLAS.Backend.*` modules.
- Check: Search the codebase for `matrix.data` or `vector.data` outside `Backend.*` modules. Only backend implementations and construction code should touch it.
- API modules (`Matrix`, `Vector`) should only access `.shape`, `.type`, and delegate `.data` operations to the backend.

**Invariant: All operations dispatch through the backend**

- Every computation function in `Matrix` and `Vector` must resolve a backend via `Config.resolve_backend/1` and call a backend callback.
- Check: Read `Matrix.mxm/4`, `Vector.reduce/3`, etc. Each should contain `backend = Config.resolve_backend(opts)` followed by `backend.matrix_mxm(a, b, semiring, opts)`.

**Invariant: Errors are structured, not raw atoms**

- All error returns must be `{:error, %GraphBLAS.Error{}}`.
- Check: Search for `{:error, :something}` where `:something` is an atom instead of a tuple. These should not exist outside test expectations.

**Invariant: Types are defined in `GraphBLAS.Types`**

- Scalar types, shapes, indices, and option types must reference `GraphBLAS.Types`.
- Check: Module-specific types (like `Matrix.t()`) can reference `Types` but should not redefine scalar types independently.

### 2. Files to review and what to look for

| File | What to check |
|------|---------------|
| `lib/ex_graphblas/backend.ex` | Every callback has a clear docstring. Return types are `{:ok, ...} \| {:error, Error.t()}`. Callback signatures match what public API modules call. |
| `lib/ex_graphblas/backend/reference.ex` | All 24 callbacks are implemented. `combine_coo_entries` correctly merges duplicates. `matrix_mxm` computes semiring products correctly. No raw data access from outside. |
| `lib/ex_graphblas/backend/suite_sparse.ex` | All 24 callbacks return `{:error, {:unsupported_operation, :not_yet_implemented, __MODULE__}}`. No accidental implementations. |
| `lib/ex_graphblas/matrix.ex` | Struct fields are `[:shape, :type, :data]`. Every public function delegates to backend. Default parameter for `semiring` is `:plus_times`. |
| `lib/ex_graphblas/vector.ex` | Same pattern as Matrix. `.size/1` shadows `Kernel.size/1` -- this is a known trade-off; verify it is documented. |
| `lib/ex_graphblas/semiring.ex` | Built-in names are unique. `resolve/1` handles both atoms and structs. Identity elements are correct for each semiring. |
| `lib/ex_graphblas/monoid.ex` | Same pattern. Identity elements are correct (0 for plus, 1 for times, etc.). |
| `lib/ex_graphblas/config.ex` | `default_backend/0` reads from application env with fallback. `resolve_backend/1` extracts `:backend` key correctly. |
| `lib/ex_graphblas/error.ex` | Structured reasons cover all error categories. `format_error/1` produces readable messages. |
| `lib/ex_graphblas/types.ex` | All 11 scalar types are listed. `validate_scalar_type/1` matches exactly. `infer_type/1` handles edge cases (empty list, mixed types). |
| `lib/ex_graphblas/mask.ex` | Complement mask creation works. `source/1` and `complement?/1` are simple accessors. |
| `lib/ex_graphblas/descriptor.ex` | Default values are correct (all "no-op": `:none`, `:merge`, `:structural`). Named constructors return expected values. |
| `config/config.exs` | Default backend is `GraphBLAS.Backend.Elixir`. Config imports environment-specific files. |
| `mix.exs` | App name is `:ex_graphblas`. Elixir version `~> 1.18`. `ex_doc` is a dev dependency. `elixirc_paths` includes test/support. |

### 3. Test coverage verification

Run `mix test` and verify:
- 107 tests pass with 0 failures
- All Reference backend operations are tested
- Error paths are tested (invalid types, dimension mismatches, out-of-bounds indices)
- Semiring and monoid resolution is tested for both atoms and structs
- SuiteSparse placeholder is tested to confirm it returns unsupported errors

### 4. Questions the reviewer should ask

1. **Is the backend behaviour complete enough for Phase 2?** The 24 callbacks cover matrix and vector lifecycle plus all core operations. If SuiteSparse needs additional callbacks (e.g., for init/finalize), they can be added in Phase 2.

2. **Is the `:data` field truly opaque?** Yes, but Elixir cannot enforce opacity at compile time. This is a documentation-driven convention. The Reference backend stores maps; SuiteSparse will store NIF resource references. The convention must be maintained in code review.

3. **Why not use Nx types instead of custom `:int64`, `:fp64`, etc.?** The prompt explicitly requires Nx-independence at the core. Custom types match GraphBLAS C API semantics and avoid coupling to Nx's type evolution. Nx conversion helpers will be added in Phase 6.

4. **Is the Elixir backend efficient enough for development?** No, and that is intentional. It uses flat tuple-key maps for correctness and inspectability. Performance claims are not made. The Elixir backend exists to prove the architecture and serve as a test oracle.

5. **Are semiring identity elements correct?** Yes, but verify:
   - `plus_times`: additive identity 0, multiplicative identity 1
   - `lor_land`: additive identity `false` (OR identity), multiplicative identity `true` (AND identity)
   - `min`: additive identity is `max(type)` (identity for min), multiplicative identity is `nil` (no identity for min alone, which is why min appears in semirings with a different additive operator)

6. **Could the module namespace collide?** `GraphBLAS` is unique enough. The prompt suggested `Ex.Matrix` etc., but that namespace is too short and collision-prone. This decision is documented.

### 5. Architecture fitness for future phases

- **Phase 2 (SuiteSparse)**: Backend behaviour is ready. SuiteSparse module just needs real implementations. Zigler integration adds a dependency but does not change the public API.
- **Phase 3 (Operations)**: All operation callbacks are already defined. Adding operations means implementing them in backends, not adding new callbacks.
- **Phase 4 (Masks/Descriptors)**: Mask and Descriptor types are defined. Wiring them into operations is a Phase 4 task.
- **Phase 5 (Algorithms)**: Algorithms will use the public API. No new modules needed for basic algorithms.
- **Phase 6 (Nx)**: Conversion helpers will be added without changing core types.
