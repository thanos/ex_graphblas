# Changelog

## 0.2.0

First public release to Hex.pm.

### Highlights

- **Three-backend architecture**: Pure Elixir (reference), SuiteSparse:GraphBLAS (native
  performance via Zigler NIFs), and ZigStub (CI verification without native dependencies).
- **Precompiled NIFs** for 6 platforms: aarch64/x86\_64 on Linux (glibc and musl) and macOS.
  End users do not need Zig or SuiteSparse installed.
- **Backend behaviour** (`GraphBLAS.Backend`) with 30 callbacks. All three backends implement
  the same contract, enforced by `@behaviour`.
- **7 graph algorithms** and a knowledge-graph query layer (`GraphBLAS.Relation`).
- **392 tests**, including property-based tests (StreamData), edge-case coverage, and
  algebraic-property verification. 0 failures, 3 skipped (SuiteSparse-only).

### Added

- `GraphBLAS.Backend` behaviour with 30 `@callback` definitions.
- `GraphBLAS.Backend.Elixir` -- pure Elixir reference backend (COO maps).
- `GraphBLAS.Backend.SuiteSparse` -- native SuiteSparse:GraphBLAS backend via Zigler NIFs.
- `GraphBLAS.Backend.ZigStub` -- minimal Zig NIF backend for CI verification.
- `backend` field in `%Matrix{}` and `%Vector{}` structs for correct dispatch.
  Inspection functions (`nvals`, `to_entries`, `to_coo`, `to_list`, `to_dense`) now
  dispatch via the owning backend.
- Conditional compilation: SuiteSparse modules live in `native/` and are only compiled
  when `EX_GRAPHBLAS_COMPILE_NATIVE=1` (test/dev) or in `dev.exs`/`config.exs`.
- Precompiled NIF distribution via ZiglerPrecompiled and GitHub Releases for 6 targets:
  `aarch64-linux-gnu`, `aarch64-linux-musl`, `aarch64-macos-none`, `x86_64-linux-gnu`,
  `x86_64-linux-musl`, `x86_64-macos-none`.
- SuiteSparse include path configurable via `SUITESPARSE_INCLUDE_PATH` environment
  variable or `:suitesparse_include_path` config key.
- 7 graph algorithms: `bfs_reach`, `bfs_levels`, `sssp`, `triangle_count`,
  `connected_components`, `degree`, `pagerank`.
- `GraphBLAS.Relation` module for knowledge-graph modelling with `traverse/4`,
  `closure/4` (with `:max_iter` option), and `fixed_point/3`.
- 12 built-in semirings including `:min_plus`, `:min_plus_fp64`, `:max_plus`,
  `:max_plus_fp64`, `:max_min`, `:max_min_fp64`.
- `sssp/3` accepts `:infinity` option (default: `1.0e18`).
- `closure/4` accepts `:max_iter` option (default: `100`).
- Core operations benchmark suite (`bench/core_ops_benchmarks.exs`).
- Edge-case test suite (22 tests): zero-dimension containers, negative dimensions,
  out-of-bounds indices, all type variants, operations on empty containers.
- Algebraic property test suite (17 tests): commutativity, associativity, transpose
  involution, dup independence, reduce correctness.
- ZigStub dimension validation guards matching the Elixir backend.
- `@doc` additions: `Raises KeyError` on `new/1` for BinaryOp, UnaryOp, Monoid,
  Semiring; `Raises ArgumentError` on `fn_for/1` for BinaryOp, UnaryOp.
- `Logger.debug` in `application.ex` rescue blocks for SuiteSparse init/finalize
  failures.
- Comprehensive guides: installation, architecture walkthrough, reference backend
  walkthrough, native backend walkthrough, graph algorithms, masks and descriptors,
  parity testing.
- Apache License 2.0.
- `coveralls.json` for coverage configuration.

### Fixed

- **Resource leaks**: Transposed matrices in `matrix_mxm`, `matrix_mxv`, `vector_vxm`
  are now freed in `after` blocks via `maybe_free_transposed/2`.
- **Ignored Zig error codes**: Replaced 22 instances of `_ = GrB_*()` with
  `try translate_info(GrB_*())` for dimension queries, type queries, descriptor set,
  JIT disable, and finalize. Only `_free` calls remain unhandled (correct -- nothing
  to do on free failure).
- **Silent type defaults**: `type_code_to_grb_type`, `semiring_from_code`,
  `monoid_from_code` now return errors instead of silently defaulting to INT64.
- **Zig build buffer overread**: Added bounds checks (`nvals > *.len`) to all 6 build
  functions in `graphblas.zig`.
- **Unsafe `hd()` call**: `algorithm.ex` uses pattern match `[{v, _} | _]` instead of
  `hd(unvisited_entries)`.
- `Vector.nvals/1`, `Vector.to_entries/1`, `Vector.to_list/1` now correctly dispatch
  to the backend that created the vector.
- `Matrix.nvals/1`, `Matrix.to_coo/1`, `Matrix.to_dense/1` same dispatch fix.
- `Matrix.set/5`, `Matrix.extract/4`, `Vector.set/4`, `Vector.extract/3` now use
  the container's backend.
- Precompiled NIF targets restricted to the 6 platforms we actually build (was
  defaulting to 12, causing 404s on `arm-linux-gnueabihf` etc.).
- `publish_hex` CI job builds GraphBLAS v9.4.5 from source instead of using Ubuntu's
  v7.4.0 `libgraphblas-dev` (which lacks `GrB_Descriptor_set_INT32`).
- Fixed `Range.new` deprecation warning.
- Fixed OTP 27 `+0.0` float literal warnings.

### Changed

- `mix.exs`: added `source_url`, `source_ref`, explicit `files:` list. Elixir
  requirement changed from `~> 1.17` to `~> 1.18`. Prod `elixirc_paths` is `["lib"]`
  only (users don't need SuiteSparse headers to compile).
- `apply/3` calls replaced with dynamic module call syntax (`mod.func(args)`) to
  satisfy Credo.
- Duplicate `max_int`/`min_int` private functions in `monoid.ex` replaced with
  `@int64_max`/`@int64_min` module attributes.
- CI: `elixir-build.yml` caches only `deps/` (not `_build/`), preventing stale NIF
  `.so` issues. Cache keys include source file hashes.
- CI: `precompiled-nifs.yml` uses `--ignore-unavailable` as a safety net during
  checksum generation.
- Guides updated to reflect completed architecture (no more "coming soon" language).
- README overhauled with three-backend architecture, environment variables table,
  and use-case examples.
- Credo strict: 0 issues. Dialyzer: 0 errors.

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

### Phase 2 -- Pure Elixir Reference Backend

- Correctness-first pure Elixir backend using `%{{row, col} => value}` maps.
- `mxm`, `mxv`, `vxm`, `ewise_add`, `ewise_mult`, `reduce`, `transpose`.
- Initial semiring set: `plus_times`, `lor_land`, `plus_min`.

### Phase 3 -- SuiteSparse Native Backend Foundation

- SuiteSparse:GraphBLAS native backend via Zigler.
- NIF resource lifecycle with dirty CPU schedulers.
- Error mapping from GrB error codes to Elixir errors.

### Phase 4 -- Core Sparse Operations Parity and Semantic Validation

- Full parity between Elixir and SuiteSparse backends.
- Shared test suites with property-based testing (StreamData).
- Extended semiring set to 10 built-in semirings.
- JIT disabled for reproducibility.

### Phase 5 -- Masks, Descriptors, and API Honing

- Structural and complement masks for all compute operations.
- Descriptor control: input transpose, output replacement.
- `set`, `extract`, `dup` for both Matrix and Vector.
- Masked mxm/vxm benchmarks.

### Phase 6 -- Graph Algorithms, Knowledge Graphs, and Query Foundations

- 7 graph algorithms: bfs_reach, bfs_levels, sssp, triangle_count,
  connected_components, degree, pagerank.
- `GraphBLAS.Relation` module for knowledge graph modelling.
- `traverse/4` for multi-hop traversal across predicates.
- `closure/4` for transitive closure.
- `fixed_point/3` generic iteration primitive.
- Added `:min_plus` and `:min_plus_fp64` semirings.
