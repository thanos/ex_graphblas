# Changelog

## 0.2.0 (Unreleased)

### Added

- `backend` field in `%Matrix{}` and `%Vector{}` structs for robust backend dispatch.
  Inspection functions (`nvals`, `to_entries`, `to_coo`, `to_list`, `to_dense`) now
  dispatch via the owning backend instead of always defaulting to Elixir.
- SuiteSparse include path configurable via `SUITESPARSE_INCLUDE_PATH` environment
  variable or `:suitesparse_include_path` config key. Platform-specific defaults.
- Core operations benchmark suite (`bench/core_ops_benchmarks.exs`).
- Benchmark runner script (`bench/run_all.exs`).
- Installation guide (`guides/installation_guide.md`).
- Apache License 2.0.
- `coveralls.json` for coverage configuration.

### Fixed

- `Vector.nvals/1`, `Vector.to_entries/1`, `Vector.to_list/1` now correctly dispatch
  to the backend that created the vector. Previously always used Elixir backend,
  causing runtime errors on SuiteSparse vectors.
- `Matrix.nvals/1`, `Matrix.to_coo/1`, `Matrix.to_dense/1` same dispatch fix.
- `Matrix.set/5`, `Matrix.extract/4`, `Vector.set/4`, `Vector.extract/3` now use
  the container's backend instead of ignoring the backend parameter.
- `config/config.exs` updated to reflect SuiteSparse backend availability.
- Removed private `vector_to_entries/1` and `matrix_to_coo/1` helpers from
  `algorithm.ex` — public API now handles backend dispatch correctly.
- Moved `bench_data.ex` from `lib/` to `bench/` (benchmark-only code).
- Fixed `Range.new` deprecation warning in `BenchData.undirected_random_graph/2`.

### Changed

- `README.md` overhauled to reflect Phases 1-6 completion.
- `mix.exs` updated with package metadata for Hex.pm.
- Credo clean (0 issues).

## 0.1.0 (Phase 1)

### Added

- Architecture, API shape, and scaffolding.
- Backend behaviour and reference implementation.
- Matrix and vector construction, inspection, and core operations.
- Semirings and monoids (built-in set).
- Masks and descriptors (type definitions).
- Configuration mechanism for backend selection.
- Full test suite for the reference backend.

---

## Phase History

### Phase 2 — Pure Elixir Reference Backend

- Correctness-first pure Elixir backend using `%{{row, col} => value}` maps.
- `mxm`, `mxv`, `vxm`, `ewise_add`, `ewise_mult`, `reduce`, `transpose`.
- Initial semiring set: `plus_times`, `lor_land`, `plus_min`.

### Phase 3 — SuiteSparse Native Backend Foundation

- SuiteSparse:GraphBLAS native backend via Zigler.
- NIF resource lifecycle with dirty CPU schedulers.
- Error mapping from GrB error codes to Elixir errors.

### Phase 4 — Core Sparse Operations Parity and Semantic Validation

- Full parity between Elixir and SuiteSparse backends.
- Shared test suites with property-based testing (StreamData).
- Extended semiring set to 10 built-in semirings.
- JIT disabled for reproducibility.

### Phase 5 — Masks, Descriptors, and API Honing

- Structural and complement masks for all compute operations.
- Descriptor control: input transpose, output replacement.
- `set`, `extract`, `dup` for both Matrix and Vector.
- Masked mxm/vxm benchmarks.

### Phase 6 — Graph Algorithms, Knowledge Graphs, and Query Foundations

- 7 graph algorithms: bfs_reach, bfs_levels, sssp, triangle_count,
  connected_components, degree, pagerank.
- `GraphBLAS.Relation` module for knowledge graph modeling.
- `traverse/4` for multi-hop traversal across predicates.
- `closure/4` for transitive closure.
- `fixed_point/3` generic iteration primitive.
- Added `:min_plus` and `:min_plus_fp64` semirings.
- 470 tests passing, 88% coverage.
