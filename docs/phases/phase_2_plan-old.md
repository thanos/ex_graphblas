# Phase 2 Implementation Plan — Native Backend Foundation (SuiteSparse Wrapper Core)

> **NOTE**: This is the old Phase 2 plan (SuiteSparse native backend). It has been superseded by the updated Phase 2 plan at `plans/phase_2_plan.md` which covers the Pure Elixir Reference Backend. The SuiteSparse work is now Phase 3.

## Prerequisite: Namespace Rename (GraphBLAS → GraphBLAS)

Before Phase 2 begins, all modules must be renamed from `GraphBLAS.*` to `GraphBLAS.*` to match the namespace specified in the project prompt. This is a search-and-replace across all files (module definitions, aliases, config, tests, docs), followed by test verification.

Files affected: every `.ex`, `.exs`, and `.md` file in the project.

---

## Goal

Build the first real native backend on top of SuiteSparse:GraphBLAS. This proves the architecture works with actual native execution, establishes the NIF boundary, and validates that opaque resource handles flow correctly through the Elixir API.

---

## Default path

Use **Zigler/Zig** for the first backend implementation.

**Rationale for Zigler over Rustler:**
- Direct C interop via `@cImport(@cInclude("GraphBLAS.h"))` — no separate C shim or Rust wrapper layer needed
- `beam.Resource` provides type-safe opaque handle management with BEAM GC integration
- Cleaner dirty scheduler annotations (`[:dirty_cpu]`, `[:dirty_io]`)
- The `.tool-versions` file already specifies `zig 0.16.0`
- If Zigler proves problematic later, the backend-neutral API means we can add a Rustler backend without touching the public API

**Trade-off:** Zigler is less mature than Rustler. Mitigation: the Elixir-facing API is backend-neutral; swapping backends is a config change, not a rewrite.

**Constraint:** Do NOT hard-code the architecture around Zig-specific assumptions. The Elixir-facing API must remain backend-neutral. Future Rustler and Port backends must remain viable.

---

## Files to Create/Modify

### New files

1. **`lib/graph_blas/backend/suite_sparse/nif.ex`** — Zigler NIF module
   - `use Zig, otp_app: :graph_blas, resources: [:GraphBLASMatrix, :GraphBLASVector]`
   - Zig `~Z` blocks wrapping SuiteSparse C functions
   - `@cImport(@cInclude("GraphBLAS.h"))` for C function bindings
   - Resource definitions: `beam.Resource(*c.GrB_Matrix, ...)` and `beam.Resource(*c.GrB_Vector, ...)`
   - Destructors calling `GrB_Matrix_free` / `GrB_Vector_free`
   - Error mapping from `GrB_Info` return codes to Elixir-friendly tuples

2. **`lib/graph_blas/backend/suite_sparse/init.ex`** — Initialization manager
   - Lazy `GrB_init(GxB_NONBLOCKING)` called exactly once on first GraphBLAS operation
   - Uses `:persistent_term` or atom for init state tracking
   - `GrB_finalize` on application stop via `Application` callback

3. **`lib/graph_blas/backend/suite_sparse/error.ex`** — Error code mapping
   - Maps all ~30 `GrB_Info` enum values to `GraphBLAS.Error` reasons
   - Documented with GraphBLAS meaning for each code

4. **`test/graph_blas/backend/suite_sparse/lifecycle_test.exs`** — Resource lifecycle tests
   - Tagged `@tag :suite_sparse` — skip if library not installed
   - Tests: create/destroy native objects, verify GC triggers `GrB_Matrix_free`
   - Tests: metadata access (shape, nvals, type) after native construction

5. **`test/graph_blas/backend/suite_sparse/error_mapping_test.exs`** — Error mapping tests
   - Tests: invalid dimensions, null pointers, type mismatches
   - Verifies Elixir error struct mapping

6. **`test/support/suite_sparse_available.ex`** — Test helper
   - Checks if SuiteSparse is installed at test startup
   - Tags tests that require the native library

### Modified files

7. **`lib/graph_blas/backend/suite_sparse.ex`** — Rewrite from placeholder to real implementation
   - Implements the 24 `GraphBLAS.Backend` behaviour callbacks
   - Delegates to `GraphBLAS.Backend.SuiteSparse.Nif` for native calls
   - Maps `GrB_Info` error codes to `GraphBLAS.Error` structs
   - Manages native resource lifecycle (creation, destruction)
   - Marks long-running operations as dirty CPU
   - Lazy initialization on first call

8. **`mix.exs`** — Add Zigler dependency and C library configuration
   - Add `{:zigler, "~> 0.15"}` to deps (verify compatible version)
   - Configure `c: [link_lib: {:system, "graphblas"}]` or equivalent
   - Update `elixirc_paths` if needed for Zigler artifacts

9. **`config/config.exs`**, **`config/dev.exs`**, **`config/test.exs`** — Add SuiteSparse configuration options
   - Library path (for non-standard installs)
   - Thread count configuration
   - Mode selection (blocking vs. nonblocking)
   - Default backend remains `GraphBLAS.Backend.Reference`

10. **All existing files** — Namespace rename from `GraphBLAS.*` to `GraphBLAS.*`

### Educational materials (publish BEFORE coding)

11. **`docs/phases/phase_2_overview.md`**
12. **`docs/phases/phase_2_review_guide.md`**
13. **`docs/phases/phase_2_concepts.md`**
14. **`docs/phases/phase_2_release_notes.md`**
15. **`guides/native_backend_walkthrough.md`**

### Educational materials (revise AFTER coding)

16. **Revise all Phase 2 docs** to reflect actual implementation details

---

## NIF Resource Lifecycle Design

### Opaque handles

GraphBLAS C objects (`GrB_Matrix`, `GrB_Vector`) are heap-allocated opaque pointers. They are wrapped in Zigler `beam.Resource` types:

```
Elixir %Matrix{} struct
  └── data field holds: reference() to Zigler Resource
       └── Zigler Resource wraps: *GrB_Matrix (C heap pointer)
            └── SuiteSparse owns the memory until GrB_Matrix_free is called
```

- `GraphBLASMatrix` resource wraps `*GrB_Matrix`
- `GraphBLASVector` resource wraps `*GrB_Vector`
- BEAM GC calls the Zigler destructor, which calls `GrB_Matrix_free` / `GrB_Vector_free`
- No large data copies: the Elixir struct holds an opaque reference, not matrix data

### Memory ownership rules

| Memory | Owner | Lifetime |
|--------|-------|----------|
| `GrB_Matrix*` handle | BEAM GC via Zigler Resource | Until GC collects the Elixir `%Matrix{}` struct |
| COO input data (Elixir list) | Elixir process | Passed to NIF, copied into GraphBLAS C memory |
| Matrix data (C heap) | SuiteSparse:GraphBLAS | Until `GrB_Matrix_free` is called by destructor |
| Result data returned to Elixir | Elixir process | COO lists created in NIF, owned by Elixir process |

**Key invariant:** No Elixir process holds a pointer into C data. All data crossing the boundary is copied. This is safe but not zero-copy. Zero-copy extraction is a Phase 7 optimization.

---

## Zigler Integration Approach

### Build configuration

```elixir
# mix.exs
def deps do
  [
    {:zigler, "~> 0.15", runtime: false},
    {:ex_doc, "~> 0.34", only: :dev, runtime: false}
  ]
end
```

### C library linking

```elixir
# In the NIF module
use Zig,
  otp_app: :graph_blas,
  c: [link_lib: {:system, "graphblas"}],
  resources: [:GraphBLASMatrix, :GraphBLASVector],
  nifs: [
    graphblas_init: [:dirty_cpu],
    graphblas_finalize: [:dirty_cpu],
    matrix_new: [],
    matrix_build_fp64: [:dirty_cpu],
    matrix_nrows: [],
    matrix_ncols: [],
    matrix_nvals: [],
    matrix_free: [],
    # ... etc
  ]
```

### C function wrapping pattern

```elixir
~Z"""
const c = @cImport(@cInclude("GraphBLAS.h"));
const beam = @import("beam");
const root = @import("root");

pub const GraphBLASMatrix = beam.Resource(*c.GrB_Matrix, root, .{
    .Callbacks = struct {
        pub fn dtor(m: **c.GrB_Matrix) void {
            _ = c.GrB_free(@ptrCast(m));
        }
    }
});

pub fn matrix_new(nrows: u64, ncols: u64) !GraphBLASMatrix {
    var m: c.GrB_Matrix = undefined;
    const info = c.GrB_Matrix_new(&m, c.GrB_FP64, nrows, ncols);
    if (info != c.GrB_SUCCESS) return error.GraphBLASError;
    return GraphBLASMatrix.create(&m, .{});
}
"""
```

---

## SuiteSparse:GraphBLAS Build Path

### Supported installation modes

1. **System library (recommended for Phase 2):** Link via `{:system, "graphblas"}`. User installs SuiteSparse via package manager (e.g., `brew install suite-sparse`, `apt install libgraphblas-dev`).

2. **Custom path:** Configure via `config :graph_blas, suite_sparse_path: "/usr/local/lib"`. Mix compile task adds the path.

3. **Bundled source (deferred to Phase 7):** Compile SuiteSparse from source as part of the Mix build. Complex cross-platform concern — not Phase 2 scope.

### Validation

- At compile time: Zigler will fail to link if `libgraphblas` is not found
- At runtime: `graphblas_init/0` checks `GrB_init` return code and returns descriptive error if library is missing or incompatible

---

## Minimal API Surface for Phase 2

**Must implement in Phase 2:**

| Callback | Rationale |
|----------|-----------|
| `matrix_new` | Proves native resource creation lifecycle |
| `matrix_from_coo` | Proves data ingestion from Elixir to C |
| `matrix_nvals` | Proves metadata extraction |
| `matrix_shape` | Proves metadata extraction |
| `matrix_type` | Proves metadata extraction |
| `matrix_to_coo` | Proves data extraction from C to Elixir |
| `vector_new` | Proves vector resource lifecycle |
| `vector_from_entries` | Proves vector data ingestion |
| `vector_nvals` | Proves vector metadata |
| `vector_size` | Proves vector metadata |
| `vector_type` | Proves vector metadata |
| `vector_to_entries` | Proves vector data extraction |

**Deferring to Phase 3:**

| Callback | Reason |
|----------|--------|
| `matrix_mxm` | Compute operation — needs semiring wiring into C API |
| `matrix_mxv` | Compute operation |
| `matrix_vxm` (via vector) | Compute operation |
| `matrix_ewise_add` | Compute operation |
| `matrix_ewise_mult` | Compute operation |
| `matrix_reduce` | Compute operation |
| `matrix_transpose` | Compute operation |
| `vector_vxm` | Compute operation |
| `vector_ewise_add` | Compute operation |
| `vector_ewise_mult` | Compute operation |
| `vector_reduce` | Compute operation |

Phase 2 proves the **lifecycle** (create, use, destroy) is correct. Phase 3 adds the **compute** operations.

---

## Error Mapping Strategy

### GrB_Info to GraphBLAS.Error mapping

| GrB_Info value | Integer | GraphBLAS.Error reason |
|----------------|---------|----------------------|
| `GrB_SUCCESS` | 0 | `:ok` (no error) |
| `GrB_NO_VALUE` | 1 | `{:empty_collection, detail}` |
| `GrB_UNINITIALIZED_OBJECT` | -1 | `{:null_handle, :matrix_or_vector}` |
| `GrB_INVALID_OBJECT` | -2 | `{:invalid_object, detail}` |
| `GrB_NULL_POINTER` | -3 | `{:null_pointer, detail}` |
| `GrB_INVALID_VALUE` | -4 | `{:invalid_argument, detail}` |
| `GrB_INVALID_INDEX` | -5 | `{:index_out_of_bounds, idx, dim, size}` |
| `GrB_DIMENSION_MISMATCH` | -6 | `{:dimension_mismatch, expected, actual}` |
| `GrB_DOMAIN_MISMATCH` | -7 | `{:type_mismatch, expected, actual}` |
| `GrB_OUTPUT_NOT_EMPTY` | -8 | `{:invalid_argument, "output not empty"}` |
| `GrB_OUT_OF_MEMORY` | -102 | `{:backend_error, SuiteSparse, :out_of_memory}` |
| `GrB_INSUFFICIENT_SPACE` | -103 | `{:backend_error, SuiteSparse, :insufficient_space}` |
| `GrB_PANIC` | -101 | `{:backend_error, SuiteSparse, :panic}` |

(Full mapping in `lib/graph_blas/backend/suite_sparse/error.ex`)

---

## Dirty Scheduler Strategy

| Operation | Scheduler | Rationale |
|-----------|-----------|-----------|
| `GrB_init` | `dirty_cpu` | One-time, may be CPU-heavy |
| `GrB_finalize` | `dirty_cpu` | One-time, cleanup |
| `GrB_Matrix_new` | default (synchronous) | Fast O(1) allocation |
| `GrB_Matrix_build` | `dirty_cpu` | O(nnz) data copy from Elixir to C |
| `GrB_Matrix_nrows/nvals` | default | O(1) metadata access |
| `GrB_Vector_new` | default | Fast O(1) allocation |
| `GrB_Vector_build` | `dirty_cpu` | O(nnz) data copy |
| `GrB_free` | default | Fast deallocation (deferred to GC) |
| Future: `GrB_mxm` | `dirty_cpu` | Potentially O(nnz^1.5) work |

---

## Thread Oversubscription Mitigation

SuiteSparse:GraphBLAS uses OpenMP internally. If the BEAM is also using all cores, there is a risk of thread oversubscription.

**Phase 2 strategy:**
- Default to `GxB_NONBLOCKING` mode (non-blocking, single-threaded by default)
- Document that users should set `GxB_GLOBAL_NTHREADS` to limit OpenMP threads
- Future: allow configuration via `config :graph_blas, nthreads: N`
- The NIF layer does not manage threads itself; it delegates to SuiteSparse

---

## Init/Finalize Strategy

Use **lazy initialization**: `GrB_init(GxB_NONBLOCKING)` called exactly once on first GraphBLAS operation.

```elixir
# lib/graph_blas/backend/suite_sparse/init.ex
defmodule GraphBLAS.Backend.SuiteSparse.Init do
  @moduledoc """
  Manages SuiteSparse:GraphBLAS initialization lifecycle.
  """

  @init_key :graphblas_suitespars_init

  def ensure_initialized do
    unless :persistent_term.get(@init_key, false) do
      case GraphBLAS.Backend.SuiteSparse.Nif.graphblas_init() do
        :ok -> :persistent_term.put(@init_key, true)
        {:error, reason} -> {:error, reason}
      end
    end
    :ok
  end
end
```

`GrB_finalize` called in an `Application.stop` callback or process trap.

---

## Test Strategy

### Tier 1: Always-run tests (Reference backend)
These run on every CI, no SuiteSparse required:
- All existing Phase 1 tests continue to pass
- Reference backend remains the test oracle

### Tier 2: SuiteSparse tests (require installation)
Tagged `@tag :suite_sparse` — skip if library not installed:
- Create/destroy native matrix and verify metadata
- Create/destroy native vector and verify metadata
- COO round-trip: build matrix from COO, extract COO, verify identical
- Error cases: invalid dimensions, type mismatches
- GC: verify that native resources are freed when Elixir structs are collected

### Tier 3: Comparison tests (require installation)
- Same input to Reference and SuiteSparse backends produces identical output
- Test matrix construction, metadata, and COO extraction

### Test helper

```elixir
# test/support/suite_sparse_available.ex
defmodule GraphBLAS.Test.SuiteSparseAvailable do
  def available? do
    Code.ensure_loaded?(GraphBLAS.Backend.SuiteSparse.Nif) and
      GraphBLAS.Backend.SuiteSparse.Nif.graphblas_init() == :ok
  end
end

# In test files:
@tag :suite_sparse
@tag skip: !GraphBLAS.Test.SuiteSparseAvailable.available?()
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Zigler version incompatibility with Zig 0.16.0 | Medium | High | Pin Zigler version, test matrix in CI, have Rustler as fallback path |
| SuiteSparse not available on target system | High (for users) | Medium | Document install steps, graceful fallback to Reference backend, `:suite_sparse` test tag |
| `GrB_init` thread safety | Low | High | Use `:persistent_term` for once-only init, test concurrent calls |
| BEAM GC not collecting resources fast enough (memory leak) | Low | Medium | Document GC-managed lifecycle, provide explicit `free/1` as escape hatch |
| Zigler `beam.Resource` can't pass between modules | Medium | Low | Keep all NIF functions in single module (already planned) |
| Zigler API changes | Medium | Medium | Pin Zigler version, monitor upstream, backend-neutral API isolates changes |

---

## Open Design Questions

1. **Should we bundle SuiteSparse or require system install?** Phase 2 recommends requiring system install. Bundling is deferred to Phase 7 (hardening).

2. **Should `GrB_init` be blocking or nonblocking?** Phase 2 uses `GxB_NONBLOCKING` (SuiteSparse extension) for better BEAM compatibility. Blocking mode would stall the BEAM scheduler.

3. **Should we expose explicit `free/1` for native objects?** Yes, as an escape hatch for memory-sensitive workloads, but document that GC handles this automatically for normal use.

4. **Should Phase 2 implement any compute operations (mxm, etc.)?** No. Phase 2 scope is lifecycle only. Compute operations are Phase 3. The plan strictly follows the prompt's Phase 2 definition.

5. **How to handle the Zigler version vs Zig version mismatch?** Verify compatible Zigler version at compile time. Document exact versions in installation guide.
