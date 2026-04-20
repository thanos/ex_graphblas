defmodule GraphBLAS.Native do
  @moduledoc """
  Zigler NIF module wrapping SuiteSparse:GraphBLAS.

  This module provides the native bridge between Elixir and the
  SuiteSparse:GraphBLAS C library. All compute-heavy functions run
  on dirty CPU schedulers to avoid blocking the BEAM.

  Do not call this module directly. Use GraphBLAS.Backend.SuiteSparse
  which provides error mapping, type resolution, and struct wrapping.

  ## Pointer lifecycle

  C pointers (GrB_Matrix, GrB_Vector) are stored as usize integers
  and passed between Elixir and this NIF module. The Elixir backend
  must call matrix_free/1 and vector_free/1 to release SuiteSparse
  objects, or they will be leaked. Future phases may integrate BEAM
  GC via Zigler resources once the module boundary is resolved.
  """

  use Zig,
    otp_app: :ex_graphblas,
    c: [
      link_lib: {:system, "graphblas"},
      include_dirs: "/opt/homebrew/include/suitesparse"
    ],
    nifs: [
      # Lifecycle
      grb_init: [],
      grb_finalize: [],

      # Matrix creation / destruction
      matrix_new: [:dirty_cpu],
      matrix_free: [:dirty_cpu],

      # Matrix inspection
      matrix_nrows: [],
      matrix_ncols: [],
      matrix_nvals: [:dirty_cpu],

      # Matrix data
      matrix_build_int64: [:dirty_cpu],
      matrix_build_fp64: [:dirty_cpu],
      matrix_build_bool: [:dirty_cpu],
      matrix_extract_tuples_int64: [:dirty_cpu],
      matrix_extract_tuples_fp64: [:dirty_cpu],
      matrix_extract_tuples_bool: [:dirty_cpu],

      # Matrix computation
      matrix_mxm: [:dirty_cpu],
      matrix_mxv: [:dirty_cpu],
      matrix_transpose: [:dirty_cpu],
      matrix_ewise_add: [:dirty_cpu],
      matrix_ewise_mult: [:dirty_cpu],
      matrix_reduce_to_vector: [:dirty_cpu],

      # Vector creation / destruction
      vector_new: [:dirty_cpu],
      vector_free: [:dirty_cpu],

      # Vector inspection
      vector_size: [],
      vector_nvals: [:dirty_cpu],

      # Vector data
      vector_build_int64: [:dirty_cpu],
      vector_build_fp64: [:dirty_cpu],
      vector_build_bool: [:dirty_cpu],
      vector_extract_tuples_int64: [:dirty_cpu],
      vector_extract_tuples_fp64: [:dirty_cpu],
      vector_extract_tuples_bool: [:dirty_cpu],

      # Vector computation
      vector_vxm: [:dirty_cpu],
      vector_ewise_add: [:dirty_cpu],
      vector_ewise_mult: [:dirty_cpu],
      vector_reduce_to_scalar_int64: [:dirty_cpu],
      vector_reduce_to_scalar_fp64: [:dirty_cpu],
      vector_reduce_to_scalar_bool: [:dirty_cpu]
    ]

  ~Z"""
  const beam = @import("beam");

  // =============================================================================
  // C type declarations (manual externs to avoid @cImport)
  // =============================================================================

  const GrB_Info = c_int;
  const GrB_Index = u64;
  const GrB_Matrix = ?*anyopaque;
  const GrB_Vector = ?*anyopaque;
  const GrB_Type = ?*anyopaque;
  const GrB_Semiring = ?*anyopaque;
  const GrB_Monoid = ?*anyopaque;
  const GrB_BinaryOp = ?*anyopaque;
  const GrB_Descriptor = ?*anyopaque;

  const GrB_BLOCKING: c_int = 0;
  const GrB_SUCCESS: c_int = 0;
  const GrB_UNINITIALIZED_OBJECT: c_int = 4;
  const GrB_NULL_POINTER: c_int = 5;
  const GrB_INVALID_VALUE: c_int = 6;
  const GrB_INVALID_INDEX: c_int = 7;
  const GrB_DOMAIN_MISMATCH: c_int = 8;
  const GrB_DIMENSION_MISMATCH: c_int = 9;
  const GrB_OUTPUT_NOT_EMPTY: c_int = 10;
  const GrB_NOT_IMPLEMENTED: c_int = 11;
  const GrB_ALREADY_SET: c_int = 12;
  const GrB_PANIC: c_int = -1;
  const GrB_OUT_OF_MEMORY: c_int = -2;
  const GrB_INSUFFICIENT_SPACE: c_int = -3;
  const GrB_INVALID_OBJECT: c_int = -4;
  const GrB_INDEX_OUT_OF_BOUNDS: c_int = -5;
  const GrB_EMPTY_OBJECT: c_int = -6;

  // Type globals (resolved at runtime from SuiteSparse shared library)
  extern var GrB_BOOL: GrB_Type;
  extern var GrB_INT64: GrB_Type;
  extern var GrB_FP64: GrB_Type;

  // C function declarations
  extern fn GrB_init(mode: c_int) GrB_Info;
  extern fn GrB_finalize() GrB_Info;
  extern fn GrB_Matrix_new(A: *GrB_Matrix, thetype: GrB_Type, nrows: GrB_Index, ncols: GrB_Index) GrB_Info;
  extern fn GrB_Matrix_free(A: *GrB_Matrix) GrB_Info;
  extern fn GrB_Matrix_nrows(nrows: *GrB_Index, A: GrB_Matrix) GrB_Info;
  extern fn GrB_Matrix_ncols(ncols: *GrB_Index, A: GrB_Matrix) GrB_Info;
  extern fn GrB_Matrix_nvals(nvals: *GrB_Index, A: GrB_Matrix) GrB_Info;
  extern fn GrB_Matrix_build_INT64(A: GrB_Matrix, I: [*]const GrB_Index, J: [*]const GrB_Index, X: [*]const i64, nvals: GrB_Index, dup: GrB_BinaryOp) GrB_Info;
  extern fn GrB_Matrix_build_FP64(A: GrB_Matrix, I: [*]const GrB_Index, J: [*]const GrB_Index, X: [*]const f64, nvals: GrB_Index, dup: GrB_BinaryOp) GrB_Info;
  extern fn GrB_Matrix_build_BOOL(A: GrB_Matrix, I: [*]const GrB_Index, J: [*]const GrB_Index, X: [*]const bool, nvals: GrB_Index, dup: GrB_BinaryOp) GrB_Info;
  extern fn GrB_Matrix_extractTuples_INT64(I: [*]GrB_Index, J: [*]GrB_Index, X: [*]i64, nvals: *GrB_Index, A: GrB_Matrix) GrB_Info;
  extern fn GrB_Matrix_extractTuples_FP64(I: [*]GrB_Index, J: [*]GrB_Index, X: [*]f64, nvals: *GrB_Index, A: GrB_Matrix) GrB_Info;
  extern fn GrB_Matrix_extractTuples_BOOL(I: [*]GrB_Index, J: [*]GrB_Index, X: [*]bool, nvals: *GrB_Index, A: GrB_Matrix) GrB_Info;
  extern fn GrB_mxm(C: GrB_Matrix, Mask: GrB_Matrix, accum: GrB_BinaryOp, semiring: GrB_Semiring, A: GrB_Matrix, B: GrB_Matrix, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_mxv(w: GrB_Vector, mask: GrB_Vector, accum: GrB_BinaryOp, semiring: GrB_Semiring, A: GrB_Matrix, u: GrB_Vector, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_transpose(C: GrB_Matrix, Mask: GrB_Matrix, accum: GrB_BinaryOp, A: GrB_Matrix, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_Matrix_eWiseAdd_Monoid(C: GrB_Matrix, Mask: GrB_Matrix, accum: GrB_BinaryOp, monoid: GrB_Monoid, A: GrB_Matrix, B: GrB_Matrix, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_Matrix_eWiseMult_Monoid(C: GrB_Matrix, Mask: GrB_Matrix, accum: GrB_BinaryOp, monoid: GrB_Monoid, A: GrB_Matrix, B: GrB_Matrix, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_Matrix_reduce_Monoid(w: GrB_Vector, mask: GrB_Vector, accum: GrB_BinaryOp, monoid: GrB_Monoid, A: GrB_Matrix, desc: GrB_Descriptor) GrB_Info;
  extern fn GxB_Matrix_type(type_ptr: *GrB_Type, A: GrB_Matrix) GrB_Info;
  extern fn GxB_Vector_type(type_ptr: *GrB_Type, v: GrB_Vector) GrB_Info;
  extern fn GrB_Vector_new(v: *GrB_Vector, thetype: GrB_Type, n: GrB_Index) GrB_Info;
  extern fn GrB_Vector_free(v: *GrB_Vector) GrB_Info;
  extern fn GrB_Vector_size(n: *GrB_Index, v: GrB_Vector) GrB_Info;
  extern fn GrB_Vector_nvals(nvals: *GrB_Index, v: GrB_Vector) GrB_Info;
  extern fn GrB_Vector_build_INT64(w: GrB_Vector, I: [*]const GrB_Index, X: [*]const i64, nvals: GrB_Index, dup: GrB_BinaryOp) GrB_Info;
  extern fn GrB_Vector_build_FP64(w: GrB_Vector, I: [*]const GrB_Index, X: [*]const f64, nvals: GrB_Index, dup: GrB_BinaryOp) GrB_Info;
  extern fn GrB_Vector_build_BOOL(w: GrB_Vector, I: [*]const GrB_Index, X: [*]const bool, nvals: GrB_Index, dup: GrB_BinaryOp) GrB_Info;
  extern fn GrB_Vector_extractTuples_INT64(I: [*]GrB_Index, X: [*]i64, nvals: *GrB_Index, v: GrB_Vector) GrB_Info;
  extern fn GrB_Vector_extractTuples_FP64(I: [*]GrB_Index, X: [*]f64, nvals: *GrB_Index, v: GrB_Vector) GrB_Info;
  extern fn GrB_Vector_extractTuples_BOOL(I: [*]GrB_Index, X: [*]bool, nvals: *GrB_Index, v: GrB_Vector) GrB_Info;
  extern fn GrB_vxm(w: GrB_Vector, mask: GrB_Vector, accum: GrB_BinaryOp, semiring: GrB_Semiring, u: GrB_Vector, A: GrB_Matrix, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_Vector_eWiseAdd_Monoid(w: GrB_Vector, mask: GrB_Vector, accum: GrB_BinaryOp, monoid: GrB_Monoid, u: GrB_Vector, v: GrB_Vector, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_Vector_eWiseMult_Monoid(w: GrB_Vector, mask: GrB_Vector, accum: GrB_BinaryOp, monoid: GrB_Monoid, u: GrB_Vector, v: GrB_Vector, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_Vector_reduce_INT64(c: *i64, accum: GrB_BinaryOp, monoid: GrB_Monoid, u: GrB_Vector, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_Vector_reduce_FP64(c: *f64, accum: GrB_BinaryOp, monoid: GrB_Monoid, u: GrB_Vector, desc: GrB_Descriptor) GrB_Info;
  extern fn GrB_Vector_reduce_BOOL(c: *bool, accum: GrB_BinaryOp, monoid: GrB_Monoid, u: GrB_Vector, desc: GrB_Descriptor) GrB_Info;

  // SuiteSparse semiring globals
  extern var GrB_PLUS_TIMES_SEMIRING_INT64: GrB_Semiring;
  extern var GrB_PLUS_TIMES_SEMIRING_FP64: GrB_Semiring;
  extern var GrB_PLUS_MIN_SEMIRING_INT64: GrB_Semiring;
  extern var GrB_PLUS_MIN_SEMIRING_FP64: GrB_Semiring;
  extern var GxB_PLUS_TIMES_INT64: GrB_Semiring;
  extern var GxB_PLUS_TIMES_FP64: GrB_Semiring;
  extern var GxB_PLUS_MIN_INT64: GrB_Semiring;
  extern var GxB_PLUS_MIN_FP64: GrB_Semiring;
  extern var GxB_MAX_PLUS_INT64: GrB_Semiring;
  extern var GxB_MAX_PLUS_FP64: GrB_Semiring;
  extern var GxB_MAX_MIN_INT64: GrB_Semiring;
  extern var GxB_MAX_MIN_FP64: GrB_Semiring;
  extern var GxB_LOR_LAND_BOOL: GrB_Semiring;
  extern var GxB_LAND_LOR_BOOL: GrB_Semiring;

  // SuiteSparse monoid globals
  extern var GrB_PLUS_MONOID_INT64: GrB_Monoid;
  extern var GrB_PLUS_MONOID_FP64: GrB_Monoid;
  extern var GrB_TIMES_MONOID_INT64: GrB_Monoid;
  extern var GrB_TIMES_MONOID_FP64: GrB_Monoid;
  extern var GrB_MIN_MONOID_INT64: GrB_Monoid;
  extern var GrB_MIN_MONOID_FP64: GrB_Monoid;
  extern var GrB_MAX_MONOID_INT64: GrB_Monoid;
  extern var GrB_MAX_MONOID_FP64: GrB_Monoid;
  extern var GrB_LAND_MONOID_BOOL: GrB_Monoid;
  extern var GrB_LOR_MONOID_BOOL: GrB_Monoid;
  extern var GrB_LXOR_MONOID_BOOL: GrB_Monoid;

  // Binary ops for build duplicate resolution
  extern var GrB_PLUS_INT64: GrB_BinaryOp;
  extern var GrB_PLUS_FP64: GrB_BinaryOp;
  extern var GxB_LOR_BOOL: GrB_BinaryOp;

  // =============================================================================
  // Error translation
  // =============================================================================

  const GraphBLASError = error {
      dimension_mismatch,
      null_pointer,
      invalid_value,
      invalid_index,
      domain_mismatch,
      output_not_empty,
      not_implemented,
      already_set,
      panic_error,
      out_of_memory,
      insufficient_space,
      invalid_object,
      index_out_of_bounds,
      empty_object,
      uninitialized_object,
      unhandled_grb_error,
  };

  fn translate_info(info: GrB_Info) GraphBLASError!void {
      return switch (info) {
          GrB_SUCCESS => {},
          GrB_UNINITIALIZED_OBJECT => error.uninitialized_object,
          GrB_NULL_POINTER => error.null_pointer,
          GrB_INVALID_VALUE => error.invalid_value,
          GrB_INVALID_INDEX => error.invalid_index,
          GrB_DOMAIN_MISMATCH => error.domain_mismatch,
          GrB_DIMENSION_MISMATCH => error.dimension_mismatch,
          GrB_OUTPUT_NOT_EMPTY => error.output_not_empty,
          GrB_NOT_IMPLEMENTED => error.not_implemented,
          GrB_ALREADY_SET => error.already_set,
          GrB_PANIC => error.panic_error,
          GrB_OUT_OF_MEMORY => error.out_of_memory,
          GrB_INSUFFICIENT_SPACE => error.insufficient_space,
          GrB_INVALID_OBJECT => error.invalid_object,
          GrB_INDEX_OUT_OF_BOUNDS => error.index_out_of_bounds,
          GrB_EMPTY_OBJECT => error.empty_object,
          else => error.unhandled_grb_error,
      };
  }

  // =============================================================================
  // Type / semiring / monoid resolution
  // =============================================================================

  fn type_code_to_grb_type(code: u8) GrB_Type {
      return switch (code) {
          1 => GrB_BOOL,
          8 => GrB_INT64,
          11 => GrB_FP64,
          else => GrB_INT64,
      };
  }

  fn semiring_from_code(code: u8) GrB_Semiring {
      return switch (code) {
          1 => GrB_PLUS_TIMES_SEMIRING_INT64,
          2 => GrB_PLUS_TIMES_SEMIRING_FP64,
          3 => GrB_PLUS_MIN_SEMIRING_INT64,
          4 => GrB_PLUS_MIN_SEMIRING_FP64,
          5 => GxB_MAX_PLUS_INT64,
          6 => GxB_MAX_PLUS_FP64,
          7 => GxB_MAX_MIN_INT64,
          8 => GxB_MAX_MIN_FP64,
          9 => GxB_LOR_LAND_BOOL,
          10 => GxB_LAND_LOR_BOOL,
          else => GrB_PLUS_TIMES_SEMIRING_INT64,
      };
  }

  fn monoid_from_code(code: u8) GrB_Monoid {
      return switch (code) {
          1 => GrB_PLUS_MONOID_INT64,
          2 => GrB_PLUS_MONOID_FP64,
          3 => GrB_TIMES_MONOID_INT64,
          4 => GrB_TIMES_MONOID_FP64,
          5 => GrB_MIN_MONOID_INT64,
          6 => GrB_MIN_MONOID_FP64,
          7 => GrB_MAX_MONOID_INT64,
          8 => GrB_MAX_MONOID_FP64,
          9 => GrB_LAND_MONOID_BOOL,
          10 => GrB_LOR_MONOID_BOOL,
          11 => GrB_LXOR_MONOID_BOOL,
          else => GrB_PLUS_MONOID_INT64,
      };
  }

  // Pointer helpers: usize <-> opaque pointer conversions
  fn mat_from_ptr(ptr: usize) GrB_Matrix {
      return @ptrFromInt(ptr);
  }

  fn mat_to_ptr(matrix: GrB_Matrix) usize {
      return @intFromPtr(matrix);
  }

  fn vec_from_ptr(ptr: usize) GrB_Vector {
      return @ptrFromInt(ptr);
  }

  fn vec_to_ptr(vector: GrB_Vector) usize {
      return @intFromPtr(vector);
  }

  // =============================================================================
  // Lifecycle
  // =============================================================================

  pub fn grb_init() !void {
      const info = GrB_init(GrB_BLOCKING);
      try translate_info(info);
  }

  pub fn grb_finalize() void {
      _ = GrB_finalize();
  }

  // =============================================================================
  // Matrix creation and destruction
  // =============================================================================

  pub fn matrix_new(nrows: u64, ncols: u64, type_code: u8) !usize {
      var matrix: GrB_Matrix = null;
      const grb_type = type_code_to_grb_type(type_code);
      const info = GrB_Matrix_new(&matrix, grb_type, nrows, ncols);
      try translate_info(info);
      return mat_to_ptr(matrix);
  }

  pub fn matrix_free(ptr: usize) void {
      if (ptr == 0) return;
      var matrix: GrB_Matrix = mat_from_ptr(ptr);
      _ = GrB_Matrix_free(&matrix);
  }

  // =============================================================================
  // Matrix inspection
  // =============================================================================

  pub fn matrix_nrows(ptr: usize) !u64 {
      const matrix = mat_from_ptr(ptr);
      var nrows: u64 = undefined;
      const info = GrB_Matrix_nrows(&nrows, matrix);
      try translate_info(info);
      return nrows;
  }

  pub fn matrix_ncols(ptr: usize) !u64 {
      const matrix = mat_from_ptr(ptr);
      var ncols: u64 = undefined;
      const info = GrB_Matrix_ncols(&ncols, matrix);
      try translate_info(info);
      return ncols;
  }

  pub fn matrix_nvals(ptr: usize) !u64 {
      const matrix = mat_from_ptr(ptr);
      var nvals: u64 = undefined;
      const info = GrB_Matrix_nvals(&nvals, matrix);
      try translate_info(info);
      return nvals;
  }

  // =============================================================================
  // Matrix data loading
  // =============================================================================

  pub fn matrix_build_int64(ptr: usize, rows: []u64, cols: []u64, vals: []i64, nvals: u64) !void {
      const matrix = mat_from_ptr(ptr);
      const info = GrB_Matrix_build_INT64(matrix, rows.ptr, cols.ptr, vals.ptr, nvals, GrB_PLUS_INT64);
      try translate_info(info);
  }

  pub fn matrix_build_fp64(ptr: usize, rows: []u64, cols: []u64, vals: []f64, nvals: u64) !void {
      const matrix = mat_from_ptr(ptr);
      const info = GrB_Matrix_build_FP64(matrix, rows.ptr, cols.ptr, vals.ptr, nvals, GrB_PLUS_FP64);
      try translate_info(info);
  }

  pub fn matrix_build_bool(ptr: usize, rows: []u64, cols: []u64, vals: []bool, nvals: u64) !void {
      const matrix = mat_from_ptr(ptr);
      const info = GrB_Matrix_build_BOOL(matrix, rows.ptr, cols.ptr, vals.ptr, nvals, GxB_LOR_BOOL);
      try translate_info(info);
  }

  // =============================================================================
  // Matrix data extraction
  // =============================================================================

  pub fn matrix_extract_tuples_int64(ptr: usize, nvals: u64) !struct { rows: []u64, cols: []u64, vals: []i64, actual_nvals: u64 } {
      const matrix = mat_from_ptr(ptr);
      const alloc = beam.allocator;
      var size: u64 = nvals;
      const rows = try alloc.alloc(u64, size);
      const cols = try alloc.alloc(u64, size);
      const vals = try alloc.alloc(i64, size);
      const info = GrB_Matrix_extractTuples_INT64(rows.ptr, cols.ptr, vals.ptr, &size, matrix);
      try translate_info(info);
      return .{ .rows = rows[0..size], .cols = cols[0..size], .vals = vals[0..size], .actual_nvals = size };
  }

  pub fn matrix_extract_tuples_fp64(ptr: usize, nvals: u64) !struct { rows: []u64, cols: []u64, vals: []f64, actual_nvals: u64 } {
      const matrix = mat_from_ptr(ptr);
      const alloc = beam.allocator;
      var size: u64 = nvals;
      const rows = try alloc.alloc(u64, size);
      const cols = try alloc.alloc(u64, size);
      const vals = try alloc.alloc(f64, size);
      const info = GrB_Matrix_extractTuples_FP64(rows.ptr, cols.ptr, vals.ptr, &size, matrix);
      try translate_info(info);
      return .{ .rows = rows[0..size], .cols = cols[0..size], .vals = vals[0..size], .actual_nvals = size };
  }

  pub fn matrix_extract_tuples_bool(ptr: usize, nvals: u64) !struct { rows: []u64, cols: []u64, vals: []bool, actual_nvals: u64 } {
      const matrix = mat_from_ptr(ptr);
      const alloc = beam.allocator;
      var size: u64 = nvals;
      const rows = try alloc.alloc(u64, size);
      const cols = try alloc.alloc(u64, size);
      const vals = try alloc.alloc(bool, size);
      const info = GrB_Matrix_extractTuples_BOOL(rows.ptr, cols.ptr, vals.ptr, &size, matrix);
      try translate_info(info);
      return .{ .rows = rows[0..size], .cols = cols[0..size], .vals = vals[0..size], .actual_nvals = size };
  }

  // =============================================================================
  // Matrix computation
  // =============================================================================

  pub fn matrix_mxm(a_ptr: usize, b_ptr: usize, semiring_code: u8) !usize {
      const a = mat_from_ptr(a_ptr);
      const b = mat_from_ptr(b_ptr);
      const semiring = semiring_from_code(semiring_code);
      var nrows_a: u64 = undefined;
      var ncols_b: u64 = undefined;
      _ = GrB_Matrix_nrows(&nrows_a, a);
      _ = GrB_Matrix_ncols(&ncols_b, b);
      var a_type: GrB_Type = null;
      _ = GxB_Matrix_type(&a_type, a);
      var result: GrB_Matrix = null;
      const info_new = GrB_Matrix_new(&result, a_type, nrows_a, ncols_b);
      try translate_info(info_new);
      const info = GrB_mxm(result, null, null, semiring, a, b, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Matrix_free(&result);
          try translate_info(info);
      }
      return mat_to_ptr(result);
  }

  pub fn matrix_mxv(matrix_ptr: usize, vector_ptr: usize, semiring_code: u8) !usize {
      const matrix = mat_from_ptr(matrix_ptr);
      const vector = vec_from_ptr(vector_ptr);
      const semiring = semiring_from_code(semiring_code);
      var nrows: u64 = undefined;
      _ = GrB_Matrix_nrows(&nrows, matrix);
      var mat_type: GrB_Type = null;
      _ = GxB_Matrix_type(&mat_type, matrix);
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, mat_type, nrows);
      try translate_info(info_new);
      const info = GrB_mxv(result, null, null, semiring, matrix, vector, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  pub fn matrix_transpose(ptr: usize) !usize {
      const matrix = mat_from_ptr(ptr);
      var nrows: u64 = undefined;
      var ncols: u64 = undefined;
      _ = GrB_Matrix_nrows(&nrows, matrix);
      _ = GrB_Matrix_ncols(&ncols, matrix);
      var mat_type: GrB_Type = null;
      _ = GxB_Matrix_type(&mat_type, matrix);
      var result: GrB_Matrix = null;
      const info_new = GrB_Matrix_new(&result, mat_type, ncols, nrows);
      try translate_info(info_new);
      const info = GrB_transpose(result, null, null, matrix, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Matrix_free(&result);
          try translate_info(info);
      }
      return mat_to_ptr(result);
  }

  pub fn matrix_ewise_add(a_ptr: usize, b_ptr: usize, monoid_code: u8) !usize {
      const a = mat_from_ptr(a_ptr);
      const b = mat_from_ptr(b_ptr);
      const monoid = monoid_from_code(monoid_code);
      var nrows: u64 = undefined;
      var ncols: u64 = undefined;
      _ = GrB_Matrix_nrows(&nrows, a);
      _ = GrB_Matrix_ncols(&ncols, a);
      var a_type: GrB_Type = null;
      _ = GxB_Matrix_type(&a_type, a);
      var result: GrB_Matrix = null;
      const info_new = GrB_Matrix_new(&result, a_type, nrows, ncols);
      try translate_info(info_new);
      const info = GrB_Matrix_eWiseAdd_Monoid(result, null, null, monoid, a, b, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Matrix_free(&result);
          try translate_info(info);
      }
      return mat_to_ptr(result);
  }

  pub fn matrix_ewise_mult(a_ptr: usize, b_ptr: usize, monoid_code: u8) !usize {
      const a = mat_from_ptr(a_ptr);
      const b = mat_from_ptr(b_ptr);
      const monoid = monoid_from_code(monoid_code);
      var nrows: u64 = undefined;
      var ncols: u64 = undefined;
      _ = GrB_Matrix_nrows(&nrows, a);
      _ = GrB_Matrix_ncols(&ncols, a);
      var a_type: GrB_Type = null;
      _ = GxB_Matrix_type(&a_type, a);
      var result: GrB_Matrix = null;
      const info_new = GrB_Matrix_new(&result, a_type, nrows, ncols);
      try translate_info(info_new);
      const info = GrB_Matrix_eWiseMult_Monoid(result, null, null, monoid, a, b, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Matrix_free(&result);
          try translate_info(info);
      }
      return mat_to_ptr(result);
  }

  pub fn matrix_reduce_to_vector(matrix_ptr: usize, monoid_code: u8) !usize {
      const matrix = mat_from_ptr(matrix_ptr);
      const monoid = monoid_from_code(monoid_code);
      var nrows: u64 = undefined;
      _ = GrB_Matrix_nrows(&nrows, matrix);
      var mat_type: GrB_Type = null;
      _ = GxB_Matrix_type(&mat_type, matrix);
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, mat_type, nrows);
      try translate_info(info_new);
      const info = GrB_Matrix_reduce_Monoid(result, null, null, monoid, matrix, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  // =============================================================================
  // Vector creation and destruction
  // =============================================================================

  pub fn vector_new(size: u64, type_code: u8) !usize {
      var vector: GrB_Vector = null;
      const grb_type = type_code_to_grb_type(type_code);
      const info = GrB_Vector_new(&vector, grb_type, size);
      try translate_info(info);
      return vec_to_ptr(vector);
  }

  pub fn vector_free(ptr: usize) void {
      if (ptr == 0) return;
      var vector: GrB_Vector = vec_from_ptr(ptr);
      _ = GrB_Vector_free(&vector);
  }

  // =============================================================================
  // Vector inspection
  // =============================================================================

  pub fn vector_size(ptr: usize) !u64 {
      const vector = vec_from_ptr(ptr);
      var size: u64 = undefined;
      const info = GrB_Vector_size(&size, vector);
      try translate_info(info);
      return size;
  }

  pub fn vector_nvals(ptr: usize) !u64 {
      const vector = vec_from_ptr(ptr);
      var nvals: u64 = undefined;
      const info = GrB_Vector_nvals(&nvals, vector);
      try translate_info(info);
      return nvals;
  }

  // =============================================================================
  // Vector data loading
  // =============================================================================

  pub fn vector_build_int64(ptr: usize, indices: []u64, vals: []i64, nvals: u64) !void {
      const vector = vec_from_ptr(ptr);
      const info = GrB_Vector_build_INT64(vector, indices.ptr, vals.ptr, nvals, GrB_PLUS_INT64);
      try translate_info(info);
  }

  pub fn vector_build_fp64(ptr: usize, indices: []u64, vals: []f64, nvals: u64) !void {
      const vector = vec_from_ptr(ptr);
      const info = GrB_Vector_build_FP64(vector, indices.ptr, vals.ptr, nvals, GrB_PLUS_FP64);
      try translate_info(info);
  }

  pub fn vector_build_bool(ptr: usize, indices: []u64, vals: []bool, nvals: u64) !void {
      const vector = vec_from_ptr(ptr);
      const info = GrB_Vector_build_BOOL(vector, indices.ptr, vals.ptr, nvals, GxB_LOR_BOOL);
      try translate_info(info);
  }

  // =============================================================================
  // Vector data extraction
  // =============================================================================

  pub fn vector_extract_tuples_int64(ptr: usize, nvals: u64) !struct { indices: []u64, vals: []i64, actual_nvals: u64 } {
      const vector = vec_from_ptr(ptr);
      const alloc = beam.allocator;
      var size: u64 = nvals;
      const indices = try alloc.alloc(u64, size);
      const vals = try alloc.alloc(i64, size);
      const info = GrB_Vector_extractTuples_INT64(indices.ptr, vals.ptr, &size, vector);
      try translate_info(info);
      return .{ .indices = indices[0..size], .vals = vals[0..size], .actual_nvals = size };
  }

  pub fn vector_extract_tuples_fp64(ptr: usize, nvals: u64) !struct { indices: []u64, vals: []f64, actual_nvals: u64 } {
      const vector = vec_from_ptr(ptr);
      const alloc = beam.allocator;
      var size: u64 = nvals;
      const indices = try alloc.alloc(u64, size);
      const vals = try alloc.alloc(f64, size);
      const info = GrB_Vector_extractTuples_FP64(indices.ptr, vals.ptr, &size, vector);
      try translate_info(info);
      return .{ .indices = indices[0..size], .vals = vals[0..size], .actual_nvals = size };
  }

  pub fn vector_extract_tuples_bool(ptr: usize, nvals: u64) !struct { indices: []u64, vals: []bool, actual_nvals: u64 } {
      const vector = vec_from_ptr(ptr);
      const alloc = beam.allocator;
      var size: u64 = nvals;
      const indices = try alloc.alloc(u64, size);
      const vals = try alloc.alloc(bool, size);
      const info = GrB_Vector_extractTuples_BOOL(indices.ptr, vals.ptr, &size, vector);
      try translate_info(info);
      return .{ .indices = indices[0..size], .vals = vals[0..size], .actual_nvals = size };
  }

  // =============================================================================
  // Vector computation
  // =============================================================================

  pub fn vector_vxm(vector_ptr: usize, matrix_ptr: usize, semiring_code: u8) !usize {
      const vector = vec_from_ptr(vector_ptr);
      const matrix = mat_from_ptr(matrix_ptr);
      const semiring = semiring_from_code(semiring_code);
      var ncols: u64 = undefined;
      _ = GrB_Matrix_ncols(&ncols, matrix);
      var vec_type: GrB_Type = null;
      _ = GxB_Vector_type(&vec_type, vector);
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, vec_type, ncols);
      try translate_info(info_new);
      const info = GrB_vxm(result, null, null, semiring, vector, matrix, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  pub fn vector_ewise_add(a_ptr: usize, b_ptr: usize, monoid_code: u8) !usize {
      const a = vec_from_ptr(a_ptr);
      const b = vec_from_ptr(b_ptr);
      const monoid = monoid_from_code(monoid_code);
      var size: u64 = undefined;
      _ = GrB_Vector_size(&size, a);
      var a_type: GrB_Type = null;
      _ = GxB_Vector_type(&a_type, a);
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, a_type, size);
      try translate_info(info_new);
      const info = GrB_Vector_eWiseAdd_Monoid(result, null, null, monoid, a, b, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  pub fn vector_ewise_mult(a_ptr: usize, b_ptr: usize, monoid_code: u8) !usize {
      const a = vec_from_ptr(a_ptr);
      const b = vec_from_ptr(b_ptr);
      const monoid = monoid_from_code(monoid_code);
      var size: u64 = undefined;
      _ = GrB_Vector_size(&size, a);
      var a_type: GrB_Type = null;
      _ = GxB_Vector_type(&a_type, a);
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, a_type, size);
      try translate_info(info_new);
      const info = GrB_Vector_eWiseMult_Monoid(result, null, null, monoid, a, b, null);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  pub fn vector_reduce_to_scalar_int64(ptr: usize, monoid_code: u8) !i64 {
      const vector = vec_from_ptr(ptr);
      const monoid = monoid_from_code(monoid_code);
      var result: i64 = 0;
      const info = GrB_Vector_reduce_INT64(&result, null, monoid, vector, null);
      try translate_info(info);
      return result;
  }

  pub fn vector_reduce_to_scalar_fp64(ptr: usize, monoid_code: u8) !f64 {
      const vector = vec_from_ptr(ptr);
      const monoid = monoid_from_code(monoid_code);
      var result: f64 = 0.0;
      const info = GrB_Vector_reduce_FP64(&result, null, monoid, vector, null);
      try translate_info(info);
      return result;
  }

  pub fn vector_reduce_to_scalar_bool(ptr: usize, monoid_code: u8) !bool {
      const vector = vec_from_ptr(ptr);
      const monoid = monoid_from_code(monoid_code);
      var result: bool = false;
      const info = GrB_Vector_reduce_BOOL(&result, null, monoid, vector, null);
      try translate_info(info);
      return result;
  }
  """
end
