# Phase 2 Plan — Pure Elixir Reference Backend

## Phase goals

Build a correctness-first, fully inspectable, intentionally naive pure Elixir reference backend that serves as:

1. **Semantic oracle** — the authoritative definition of what each operation should produce
2. **Debugging aid** — easy to inspect, trace, and reason about
3. **Regression baseline** — future native backends must produce identical results
4. **Tutorial vehicle** — the simplest readable implementation for learning GraphBLAS concepts
5. **API validation layer** — proves the backend behaviour contract is well-defined

This backend must be **small, clear, intentionally naive, and fully inspectable**. It is NOT a performance project.

## Scope

### What this phase includes

- **Namespace rename**: `ExGraphBLAS.*` → `GraphBLAS.*` across all files (app name stays `:ex_graphblas`)
- **Backend rename**: `ExGraphBLAS.Backend.Reference` → `GraphBLAS.Backend.Elixir`
- **Simplify representation**: Change internal matrix storage from nested maps `%{row => %{col => value}}` to flat tuple-key maps `%{{row, col} => value}` as the prompt suggests
- **Validate all existing operations** against explicit expected values (semantic correctness tests)
- **Add dense conversion helpers** for debugging and examples (`Matrix.to_dense/1`, `Vector.to_list/1`)
- **Strengthen regression test suite** — every operation must have small, exact, hand-verified expected outputs
- **Update behaviour module** to reflect the renamed namespace
- **Update all documentation** to use `GraphBLAS` namespace
- **Educational package** explaining why a reference backend exists and how it works

### What this phase explicitly does NOT include

- Performance optimization (the reference backend is intentionally naive)
- Concurrency or parallelism
- Native/NIF code (SuiteSparse is Phase 3)
- Port backend
- Nx backend or integration
- Graph algorithms (unless as tiny examples in tests)
- Sophisticated CSR/CSC storage engineering
- New operations beyond what Phase 1 already defined (mxm, mxv, vxm, ewise_add, ewise_mult, reduce, transpose)
- Any API changes that break backend-neutrality

---

## Files expected to be changed or created

### Namespace rename (all existing files)

Every file under `lib/`, `test/`, `config/`, and `docs/` that references `ExGraphBLAS` must be updated to `GraphBLAS`. This includes:

- Module definitions (`defmodule ExGraphBLAS.X` → `defmodule GraphBLAS.X`)
- Alias statements (`alias ExGraphBLAS.X` → `alias GraphBLAS.X`)
- Struct references (`%ExGraphBLAS.Matrix{}` → `%GraphBLAS.Matrix{}`)
- Config references (`config :ex_graphblas, ...` stays — app name unchanged)
- Application env keys stay `:ex_graphblas` (app name), but module references change
- Test module names
- Documentation references

Estimated files: ~20-25 source files + ~14 test files + ~5 doc files

### Representation change

| File | Change |
|------|--------|
| `lib/graph_blas/backend/elixir.ex` | Rewrite from nested maps to `%{{row, col} => value}` for matrices, `%{index => value}` for vectors. Simplify all operations accordingly. |

The flat representation is:
- **Matrix data**: `%{{row, col} => value}` — single-level map with tuple keys
- **Vector data**: `%{index => value}` — flat map
- Both are trivially inspectable, pattern-matchable, and serializable

This replaces the current nested map `%{row => %{col => value}}` which requires two-level lookups.

### New files

| File | Purpose |
|------|---------|
| `lib/graph_blas/matrix/dense.ex` | `Matrix.to_dense/1` — convert sparse matrix to list-of-lists for debugging |
| `lib/graph_blas/vector/dense.ex` | `Vector.to_list/1` — convert sparse vector to dense list for debugging |

### Backend rename

| Before | After |
|--------|-------|
| `ExGraphBLAS.Backend.Reference` | `GraphBLAS.Backend.Elixir` |

The `SuiteSparse` placeholder also gets renamed:
| Before | After |
|--------|-------|
| `ExGraphBLAS.Backend.SuiteSparse` | `GraphBLAS.Backend.SuiteSparse` |

---

## Public API changes

The public API surface does not change in semantics or behavior. Only the module namespace changes:

| Before | After |
|--------|-------|
| `ExGraphBLAS.Matrix` | `GraphBLAS.Matrix` |
| `ExGraphBLAS.Vector` | `GraphBLAS.Vector` |
| `ExGraphBLAS.Scalar` | `GraphBLAS.Scalar` |
| `ExGraphBLAS.Semiring` | `GraphBLAS.Semiring` |
| `ExGraphBLAS.Monoid` | `GraphBLAS.Monoid` |
| `ExGraphBLAS.BinaryOp` | `GraphBLAS.BinaryOp` |
| `ExGraphBLAS.UnaryOp` | `GraphBLAS.UnaryOp` |
| `ExGraphBLAS.Mask` | `GraphBLAS.Mask` |
| `ExGraphBLAS.Descriptor` | `GraphBLAS.Descriptor` |
| `ExGraphBLAS.Backend` | `GraphBLAS.Backend` |
| `ExGraphBLAS.Backend.Reference` | `GraphBLAS.Backend.Elixir` |
| `ExGraphBLAS.Backend.SuiteSparse` | `GraphBLAS.Backend.SuiteSparse` |
| `ExGraphBLAS.Types` | `GraphBLAS.Types` |
| `ExGraphBLAS.Error` | `GraphBLAS.Error` |
| `ExGraphBLAS.Config` | `GraphBLAS.Config` |

New additions:
| Module | Purpose |
|--------|---------|
| `GraphBLAS.Matrix` (add function) | `to_dense/1` — returns list-of-lists |
| `GraphBLAS.Vector` (add function) | `to_list/1` — returns a dense list |

No existing public functions are removed or changed in semantics.

---

## Backend/API implications

The `GraphBLAS.Backend` behaviour callback signatures do not change. The behaviour module itself gets renamed from `ExGraphBLAS.Backend` to `GraphBLAS.Backend`.

The `GraphBLAS.Backend.Elixir` module implements the same 24 callbacks as the current `ExGraphBLAS.Backend.Reference`, but with simpler internal representation.

Internal data change:
- **Before**: Matrix data is `%{entries: %{row => %{col => value}}, nrows: n, ncols: m, type: t}`
- **After**: Matrix data is `%{entries: %{{row, col} => value}, nrows: n, ncols: m, type: t}`

The `data` field remains opaque. The change is purely internal to the Elixir backend.

---

## Testing strategy

### Tier 1: Smoke tests (always run)
- All existing Phase 1 tests, renamed to `GraphBLAS` namespace
- These verify the public API works correctly with the Elixir backend

### Tier 2: Semantic correctness tests (new, extensive)
Each operation gets explicit hand-verified expected outputs:

- **Matrix construction from COO**: Known inputs produce known outputs
- **mxm with plus_times semiring**: Small adjacency matrices with hand-computed products
- **mxm with lor_land semiring**: Boolean adjacency matrices with hand-computed reachability
- **mxv**: Known matrix-vector products
- **vxm**: Known vector-matrix products
- **ewise_add**: Union of structural positions
- **ewise_mult**: Intersection of structural positions
- **reduce**: Row/column reductions
- **transpose**: Known transpositions

Each test must:
1. State the mathematical operation being tested
2. Show the expected result computed by hand
3. Verify the backend produces the exact same result

### Tier 3: Regression oracle framework
- A test helper that runs the same inputs through the Elixir backend and can later be extended to also run through the SuiteSparse backend
- Property: same inputs → same outputs, regardless of backend
- This framework will be used in Phase 4 (parity validation)

### Tier 4: Dense conversion tests
- `Matrix.to_dense/1` produces correct list-of-lists representation
- `Vector.to_list/1` produces correct list representation including default values

### What remains untested
- Native backend operations (Phase 3)
- Performance characteristics (intentionally not tested — not a goal)
- Concurrency (intentionally not tested — not a goal)
- Large-scale sparse operations (correct but slow; not tested at scale)

---

## Risks / uncertainties

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Namespace rename breaks something subtle | Medium | Medium | Full test suite pass required; grep for all `ExGraphBLAS` references |
| Flat tuple-key maps slower than nested maps for column access | High | Low | Acceptable — performance is NOT a goal. Flat maps are more inspectable |
| `GraphBLAS` module name conflicts with an existing Hex package | Low | High | Check hex.pm before finalizing; `GraphBLAS` name is unlikely to conflict |
| Existing Phase 1 tests become brittle during rename | Medium | Medium | Systematic rename with test verification at each step |
| Dense conversion helpers encourage wrong patterns | Low | Low | Document that `to_dense` is for debugging only, not production |

---

## Alternatives considered

### Alternative 1: Keep nested map representation
- Pro: Slightly faster column access
- Con: Harder to inspect, harder to reason about, two-level lookup
- Decision: Flat tuple-key maps are simpler and more reviewable. The prompt explicitly suggests `%{{row, col} => value}`.

### Alternative 2: Keep `ExGraphBLAS` namespace
- Pro: No rename needed, less churn
- Con: Prompt explicitly specifies `GraphBLAS` namespace; `Ex` prefix is redundant
- Decision: Follow the prompt. Rename is mechanical but important for the public API identity.

### Alternative 3: Cache the backend behavior in public API functions
- Pro: Slightly faster backend resolution
- Con: Adds complexity, makes testing harder, premature optimization for a reference backend
- Decision: Simple `Config.resolve_backend(opts)` call per operation. Keep it simple.

### Alternative 4: Use structs for semiring/monoid operators instead of atoms
- Pro: More type-safe
- Con: Atoms are simpler for Phase 2; can be refined later
- Decision: Keep atoms for built-in semirings/monoids, allow structs for custom ones (already the design)

---

## What will explicitly NOT be done in this phase

1. **No native/NIF code** — SuiteSparse is Phase 3
2. **No performance optimization** — the reference backend is intentionally naive
3. **No new operations beyond what Phase 1 already defines** — mxm, mxv, vxm, ewise_add, ewise_mult, reduce, transpose
4. **No Nx integration** — Phase 7
5. **No graph algorithms** — Phase 6
6. **No masks wired into operations** — Phase 5
7. **No descriptors wired into operations** — Phase 5
8. **No concurrency** — not a goal for the reference backend
9. **No CSR/CSC storage** — flat maps are sufficient and more inspectable

---

## Reviewer approval checklist

- [ ] Namespace rename is complete: no remaining `ExGraphBLAS` references in source
- [ ] Backend renamed to `GraphBLAS.Backend.Elixir` (not `Reference`)
- [ ] All 107+ Phase 1 tests pass under the new `GraphBLAS` namespace
- [ ] Flat tuple-key map representation is used in the Elixir backend
- [ ] Every operation has at least one hand-verified semantic correctness test
- [ ] Dense conversion helpers exist and are documented as debugging-only
- [ ] No performance claims are made anywhere in the codebase
- [ ] Every public module has `@moduledoc`, `@doc`, and `@spec`
- [ ] `mix test` passes with 0 failures
- [ ] Educational package explains why the reference backend exists
- [ ] Educational package explains the flat map representation
- [ ] Educational package explains how semirings change what mxm computes
- [ ] Plan is saved at `plans/phase_2_plan.md`
- [ ] Pre-coding educational package exists before implementation begins