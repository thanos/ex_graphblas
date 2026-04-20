# Phase 2 Review Guide

**Status: IMPLEMENTED — USE THIS AS A CHECKLIST FOR REVIEW**

## What to review before approving Phase 2

This guide lists the specific things a reviewer should verify before accepting Phase 2.

### 1. Namespace rename completeness

The rename from `ExGraphBLAS` to `GraphBLAS` must be complete. Check:

- [ ] No remaining `ExGraphBLAS` references in `lib/` source files
- [ ] No remaining `ExGraphBLAS` references in `test/` files
- [ ] No remaining `ExGraphBLAS` references in `config/` files
- [ ] No remaining `ExGraphBLAS` references in `docs/` or `guides/`
- [ ] The `mix.exs` app name is still `:ex_graphblas` (this should NOT change)
- [ ] The `mix.exs` module name is `GraphBLAS.MixProject`
- [ ] `grep -r "ExGraphBLAS" lib/ test/ config/` returns zero results

### 2. Backend rename

- [ ] `ExGraphBLAS.Backend.Reference` is now `GraphBLAS.Backend.Elixir`
- [ ] `ExGraphBLAS.Backend.SuiteSparse` is now `GraphBLAS.Backend.SuiteSparse`
- [ ] The default backend in `config/config.exs` points to `GraphBLAS.Backend.Elixir`
- [ ] All config files reference `GraphBLAS.Backend.Elixir`

### 3. Representation change

- [ ] Matrix data uses flat tuple-key maps: `%{{row, col} => value}` (not nested `%{row => %{col => value}}`)
- [ ] Vector data uses flat maps: `%{index => value}`
- [ ] The `data` field in Matrix and Vector structs remains opaque to callers
- [ ] All backend operations work correctly with the new representation
- [ ] COO round-trip works: `from_coo -> to_coo` produces matching entries

### 4. Semantic correctness tests

For each operation, verify there is at least one test with hand-computed expected values:

- [ ] `Matrix.from_coo` / `Matrix.new` construction
- [ ] `Matrix.mxm` with `:plus_times` semiring
- [ ] `Matrix.mxm` with `:lor_land` semiring (boolean)
- [ ] `Matrix.mxm` with `:plus_min` semiring (multiply=min, add=plus)
- [ ] `Matrix.mxv` matrix-vector multiplication
- [ ] `Matrix.ewise_add` union of structural positions
- [ ] `Matrix.ewise_mult` intersection of structural positions
- [ ] `Matrix.reduce` row reduction
- [ ] `Matrix.transpose`
- [ ] `Vector.from_entries` / `Vector.new` construction
- [ ] `Vector.vxm` vector-matrix multiplication
- [ ] `Vector.ewise_add` and `Vector.ewise_mult`
- [ ] `Vector.reduce`

Each test should:
- State the mathematical operation being tested
- Show the expected result computed by hand
- Verify the backend produces the exact same result

### 5. Dense conversion helpers

- [ ] `Matrix.to_dense/1` exists and returns list-of-lists
- [ ] `Vector.to_list/1` exists and returns a list with default values filled in
- [ ] Both are documented as debugging-only helpers
- [ ] Neither is used in production code paths (only in tests and examples)

### 6. Invariants that must hold

- [ ] The `:data` field in Matrix and Vector structs is never pattern-matched outside backend modules
- [ ] All operations dispatch through `Config.resolve_backend/1`
- [ ] All errors are `{:error, %GraphBLAS.Error{}}` tuples
- [ ] Semiring and monoid resolution works for both atom names and structs
- [ ] The backend behaviour callbacks match what API modules call

### 7. No performance claims

Verify that nowhere in the codebase or documentation does the reference backend claim to be performant:

- [ ] No benchmarking claims in docs
- [ ] Module docs explicitly state the backend is "correct, not performant"
- [ ] No `:ets` or `:persistent_term` optimization in the Elixir backend
- [ ] No concurrent or parallel execution in the Elixir backend

### 8. Documentation quality

Every public module must have:
- [ ] `@moduledoc` explaining what it does
- [ ] `@doc` on every public function
- [ ] `@spec` type specifications
- [ ] Accurate examples where appropriate
- [ ] No decorative fluff or emojis

### 9. Test suite

- [ ] `mix test` passes with 0 failures
- [ ] Test count is at least 107 (matching Phase 1 minimum)
- [ ] New semantic correctness tests are present
- [ ] Error handling tests exist for invalid inputs

### 10. Questions the reviewer should ask

1. **Is the flat tuple-key map representation sufficient for correctness?** Yes. It supports all required operations programmatically. Row-based access is O(nnz) per row, which is acceptable for a reference backend.

2. **Why "Elixir" instead of "Reference" for the backend name?** Three reasons: (a) it clearly communicates that the implementation is pure Elixir with no native code, (b) it avoids confusion with the GraphBLAS "reference implementation" (which is SuiteSparse itself), and (c) it follows the naming convention where backends are named after their implementation technology.

3. **Could the namespace rename break downstream users?** The library has not been published to Hex yet (v0.1.0), so there are no downstream users. This is the right time to fix the namespace.

4. **Is the semantic correctness test suite sufficient for regression testing?** It should cover at least one hand-verified example per operation. Phase 4 will expand this significantly with property-based testing and larger test cases for parity validation.

5. **Are the dense conversion helpers a leaky abstraction?** They could be, if people start using `to_dense` in production code paths. The documentation explicitly warns against this. The helpers exist for debugging and teaching, not for computation.