defmodule GraphBLAS.Native.SuiteSparse do
  @moduledoc """
  Zigler NIF module wrapping SuiteSparse:GraphBLAS.

  This module provides the native bridge between Elixir and the
  SuiteSparse:GraphBLAS C library. All compute-heavy functions run
  on dirty CPU schedulers to avoid blocking the BEAM.

  Do not call this module directly. Use GraphBLAS.Backend.SuiteSparse
  which provides error mapping, type resolution, and struct wrapping.

  ## Precompiled NIFs

  When the EX_GRAPHBLAS_BUILD env variable is not set, this module
  downloads precompiled NIFs from GitHub Releases instead of compiling
  from source. Set EX_GRAPHBLAS_BUILD=1 to force local compilation
  (requires Zig and SuiteSparse:GraphBLAS installed).

  ## Include path

  The default include path is `/opt/homebrew/include/suitesparse` (macOS
  Apple Silicon). Override via the `SUITESPARSE_INCLUDE_PATH` environment
  variable or the `:suitesparse_include_path` application config. Common
  values:

  - macOS Apple Silicon: `/opt/homebrew/include/suitesparse`
  - macOS Intel: `/usr/local/include/suitesparse`
  - Linux (Debian/Ubuntu): `/usr/include/suitesparse`

  ## Pointer lifecycle

  C pointers (GrB_Matrix, GrB_Vector) are stored as usize integers
  and passed between Elixir and this NIF module. The Elixir backend
  must call matrix_free/1 and vector_free/1 to release SuiteSparse
  objects, or they will be leaked. Future phases may integrate BEAM
  GC via Zigler resources once the module boundary is resolved.
  """

  version = Mix.Project.config()[:version]

  @suitesparse_include_path Application.compile_env(
                              :ex_graphblas,
                              :suitesparse_include_path,
                              System.get_env(
                                "SUITESPARSE_INCLUDE_PATH",
                                "/opt/homebrew/include/suitesparse"
                              )
                            )

  use ZiglerPrecompiled,
    otp_app: :ex_graphblas,
    base_url: "https://github.com/thanos/ex_graphblas/releases/download/v#{version}",
    version: version,
    force_build: System.get_env("EX_GRAPHBLAS_BUILD") in ["1", "true"],
    zig_code_path: "../priv/native/suite_sparse/graphblas.zig",
    c: [
      link_lib: {:system, "graphblas"},
      include_dirs: @suitesparse_include_path
    ],
    nifs: [
      grb_init: 0,
      grb_finalize: 0,
      matrix_new: 3,
      matrix_free: 1,
      matrix_nrows: 1,
      matrix_ncols: 1,
      matrix_nvals: 1,
      matrix_build_int64: 5,
      matrix_build_fp64: 5,
      matrix_build_bool: 5,
      matrix_extract_tuples_int64: 2,
      matrix_extract_tuples_fp64: 2,
      matrix_extract_tuples_bool: 2,
      matrix_mxm: 5,
      matrix_mxv: 5,
      matrix_transpose: 3,
      matrix_ewise_add: 5,
      matrix_ewise_mult: 5,
      matrix_reduce_to_vector: 4,
      matrix_set_int64: 4,
      matrix_set_fp64: 4,
      matrix_set_bool: 4,
      matrix_extract_int64: 3,
      matrix_extract_fp64: 3,
      matrix_extract_bool: 3,
      matrix_dup: 1,
      vector_new: 2,
      vector_free: 1,
      vector_size: 1,
      vector_nvals: 1,
      vector_build_int64: 4,
      vector_build_fp64: 4,
      vector_build_bool: 4,
      vector_extract_tuples_int64: 2,
      vector_extract_tuples_fp64: 2,
      vector_extract_tuples_bool: 2,
      vector_vxm: 5,
      vector_ewise_add: 5,
      vector_ewise_mult: 5,
      vector_reduce_to_scalar_int64: 2,
      vector_reduce_to_scalar_fp64: 2,
      vector_reduce_to_scalar_bool: 2,
      vector_set_int64: 3,
      vector_set_fp64: 3,
      vector_set_bool: 3,
      vector_extract_int64: 2,
      vector_extract_fp64: 2,
      vector_extract_bool: 2,
      vector_dup: 1,
      descriptor_create: 5,
      descriptor_free: 1,
      descriptor_is_custom: 1
    ]
end
