# Phase 2 Implementation Delta

**Status: IMPLEMENTED**

This document records deviations from the Phase 2 plan and any decisions made during implementation.

## Deviations from the plan

### 1. Semiring name: `:plus_min` (not `:min_plus`)

**Plan**: The review guide listed `:min_plus` as a semiring to test.

**Actual**: The built-in semiring is named `:plus_min` (multiply=`min`, add=`plus`), matching the naming convention where the multiply operator is listed first. The test uses `:plus_min` correctly.

**Reason**: The `Semiring` module defines `:plus_min` as the name for the semiring `(min, plus)`. This is consistent with the naming pattern: `multiply_add`, so plus_min means "multiply with min, add with plus."

### 2. Test file uses `RefBackend` alias instead of `Elixir`

**Plan**: Tests were expected to call `GraphBLAS.Backend.Elixir` directly.

**Actual**: The test file `elixir_test.exs` uses `alias GraphBLAS.Backend.Elixir, as: RefBackend` and calls `RefBackend.matrix_new/4` etc.

**Reason**: `Elixir` is a reserved module name in the Elixir runtime. Using `RefBackend` as an alias avoids any naming conflicts and makes the test intent clear: these are direct backend calls, not through the public API.

### 3. No separate dense conversion modules

**Plan**: The plan listed new files `lib/graph_blas/matrix/dense.ex` and `lib/graph_blas/vector/dense.ex` for `to_dense` and `to_list`.

**Actual**: `Matrix.to_dense/1` and `Vector.to_list/1` were added directly to the existing `matrix.ex` and `vector.ex` modules. The Backend behaviour gained two new callbacks (`matrix_to_dense` and `vector_to_list`) implemented in the Elixir backend.

**Reason**: Adding new submodules for single functions creates unnecessary indirection. The functions dispatch to the backend via the same pattern as all other functions. Keeping them in the main module is simpler and more discoverable.

### 4. Backend behaviour now has 26 callbacks (was 24)

**Plan**: The Phase 1 behaviour defined 24 callbacks.

**Actual**: Two new callbacks were added: `matrix_to_dense/1` and `vector_to_list/1`. The SuiteSparse placeholder also has stubs for these.

**Reason**: Phase 2 plan explicitly called for `Matrix.to_dense/1` and `Vector.to_list/1`. These need backend callbacks, so the behaviour was extended.

### 5. `default_value/1` private helper in Elixir backend

**Plan**: Not mentioned in the plan.

**Actual**: The Elixir backend includes a `default_value/1` helper that maps scalar types to their default (implicit zero) values: `:bool` -> `false`, `:fp32/:fp64` -> `0.0`, everything else -> `0`. This is used by `matrix_to_dense` and `vector_to_list` to fill in missing entries.

**Reason**: Needed to materialize dense representations from sparse data. The helper is small, private, and type-correct.

## Items completed as planned

- Namespace rename: `ExGraphBLAS.*` -> `GraphBLAS.*` (done in Phase 1, confirmed)
- Backend rename: `Backend.Reference` -> `Backend.Elixir`
- Representation change: nested maps -> flat tuple-key maps `%{{row, col} => value}`
- All existing tests pass (136 total, up from ~107)
- Semantic correctness test suite added
- Dense conversion helpers working
- All Phase 1 docs updated to reference `Backend.Elixir` and flat maps
- `docs/phases/phase_2_plan-old.md` retained for historical reference

## Acknowledged decision: No Nx dependency

During implementation, the question was raised whether Nx or another Elixir matrix library could be leveraged for the reference backend. Analysis concluded:

- **Nx**: Dense-only, no sparse support. Would require sparse->dense conversion before every op. Defeats the purpose of being a semantic oracle.
- **Other Elixir libraries** (Tensor, Matrex, libgraph): Either inactive, dense-only, or provide graph algorithms (not sparse matrix operations). None support standard sparse formats (COO, CSR, CSC).
- **Decision**: Keep the hand-rolled flat map approach. It is the simplest correct implementation, which is exactly what a reference backend should be.