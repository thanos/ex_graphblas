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
  const GxB_JIT_OFF: c_int = 0;
  const GxB_JIT_C_CONTROL: c_int = 7029;
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
  extern fn GxB_Global_Option_set_INT32(option: c_int, value: c_int) GrB_Info;

  // Descriptor management
  extern fn GrB_Descriptor_new(desc: *GrB_Descriptor) GrB_Info;
  extern fn GrB_Descriptor_set_INT32(desc: GrB_Descriptor, field: c_int, value: c_int) GrB_Info;
  extern fn GrB_Descriptor_free(desc: *GrB_Descriptor) GrB_Info;

  // Descriptor field constants (from GraphBLAS.h)
  const GrB_OUTP: c_int = 0;
  const GrB_MASK: c_int = 1;
  const GrB_INP0: c_int = 2;
  const GrB_INP1: c_int = 3;

  // Descriptor value constants (from GraphBLAS.h)
  const GrB_REPLACE: c_int = 1;
  const GrB_COMP: c_int = 2;
  const GrB_TRAN: c_int = 3;
  const GrB_STRUCTURE: c_int = 4;
  const GrB_COMP_STRUCTURE: c_int = 6;

  // Pre-defined descriptor globals (extern)
  extern var GrB_DESC_S: GrB_Descriptor;
  extern var GrB_DESC_SC: GrB_Descriptor;
  extern var GrB_DESC_T0: GrB_Descriptor;
  extern var GrB_DESC_T1: GrB_Descriptor;
  extern var GrB_DESC_T0T1: GrB_Descriptor;
  extern var GrB_DESC_ST0: GrB_Descriptor;
  extern var GrB_DESC_ST1: GrB_Descriptor;
  extern var GrB_DESC_ST0T1: GrB_Descriptor;
  extern var GrB_DESC_SCT0: GrB_Descriptor;
  extern var GrB_DESC_SCT1: GrB_Descriptor;
  extern var GrB_DESC_SCT0T1: GrB_Descriptor;
  extern var GrB_DESC_R: GrB_Descriptor;
  extern var GrB_DESC_RS: GrB_Descriptor;
  extern var GrB_DESC_RSC: GrB_Descriptor;
  extern var GrB_DESC_RT0: GrB_Descriptor;
  extern var GrB_DESC_RT1: GrB_Descriptor;
  extern var GrB_DESC_RT0T1: GrB_Descriptor;
  extern var GrB_DESC_RST0: GrB_Descriptor;
  extern var GrB_DESC_RST1: GrB_Descriptor;
  extern var GrB_DESC_RST0T1: GrB_Descriptor;
  extern var GrB_DESC_RSCT0: GrB_Descriptor;
  extern var GrB_DESC_RSCT1: GrB_Descriptor;
  extern var GrB_DESC_RSCT0T1: GrB_Descriptor;

  // GrB_NO_VALUE — returned by extractElement when entry is structural zero
  const GrB_NO_VALUE: c_int = 1;

  // Matrix set/extract/dup
  extern fn GrB_Matrix_setElement_INT64(m: GrB_Matrix, val: i64, row: GrB_Index, col: GrB_Index) GrB_Info;
  extern fn GrB_Matrix_setElement_FP64(m: GrB_Matrix, val: f64, row: GrB_Index, col: GrB_Index) GrB_Info;
  extern fn GrB_Matrix_setElement_BOOL(m: GrB_Matrix, val: bool, row: GrB_Index, col: GrB_Index) GrB_Info;
  extern fn GrB_Matrix_extractElement_INT64(val: *i64, m: GrB_Matrix, row: GrB_Index, col: GrB_Index) GrB_Info;
  extern fn GrB_Matrix_extractElement_FP64(val: *f64, m: GrB_Matrix, row: GrB_Index, col: GrB_Index) GrB_Info;
  extern fn GrB_Matrix_extractElement_BOOL(val: *bool, m: GrB_Matrix, row: GrB_Index, col: GrB_Index) GrB_Info;
  extern fn GrB_Matrix_dup(copy: *GrB_Matrix, source: GrB_Matrix) GrB_Info;

  // Vector set/extract/dup
  extern fn GrB_Vector_setElement_INT64(v: GrB_Vector, val: i64, idx: GrB_Index) GrB_Info;
  extern fn GrB_Vector_setElement_FP64(v: GrB_Vector, val: f64, idx: GrB_Index) GrB_Info;
  extern fn GrB_Vector_setElement_BOOL(v: GrB_Vector, val: bool, idx: GrB_Index) GrB_Info;
  extern fn GrB_Vector_extractElement_INT64(val: *i64, v: GrB_Vector, idx: GrB_Index) GrB_Info;
  extern fn GrB_Vector_extractElement_FP64(val: *f64, v: GrB_Vector, idx: GrB_Index) GrB_Info;
  extern fn GrB_Vector_extractElement_BOOL(val: *bool, v: GrB_Vector, idx: GrB_Index) GrB_Info;
  extern fn GrB_Vector_dup(copy: *GrB_Vector, source: GrB_Vector) GrB_Info;

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

  fn type_code_to_grb_type(code: u8) GraphBLASError!GrB_Type {
      return switch (code) {
          1 => GrB_BOOL,
          8 => GrB_INT64,
          11 => GrB_FP64,
          else => error.invalid_value,
      };
  }

  fn semiring_from_code(code: u8) GraphBLASError!GrB_Semiring {
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
          else => error.invalid_value,
      };
  }

  fn monoid_from_code(code: u8) GraphBLASError!GrB_Monoid {
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
          else => error.invalid_value,
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
      // Disable SuiteSparse JIT compiler — pre-compiled kernels suffice
      // and JIT fails on some semirings (plus_min, etc.) returning
      // GxB_JIT_ERROR (-7001) which causes dirty_cpu NIFs to hang.
      try translate_info(GxB_Global_Option_set_INT32(GxB_JIT_C_CONTROL, GxB_JIT_OFF));
  }

  pub fn grb_finalize() !void {
      try translate_info(GrB_finalize());
  }

  // =============================================================================
  // Matrix creation and destruction
  // =============================================================================

  pub fn matrix_new(nrows: u64, ncols: u64, type_code: u8) !usize {
      var matrix: GrB_Matrix = null;
      const grb_type = try type_code_to_grb_type(type_code);
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

  fn desc_from_ptr(ptr: usize) GrB_Descriptor {
      if (ptr == 0) return null;
      return @ptrFromInt(ptr);
  }

  fn mask_mat_from_ptr(ptr: usize) GrB_Matrix {
      if (ptr == 0) return null;
      return @ptrFromInt(ptr);
  }

  fn mask_vec_from_ptr(ptr: usize) GrB_Vector {
      if (ptr == 0) return null;
      return @ptrFromInt(ptr);
  }

  pub fn matrix_mxm(a_ptr: usize, b_ptr: usize, semiring_code: u8, mask_ptr: usize, desc_ptr: usize) !usize {
      const a = mat_from_ptr(a_ptr);
      const b = mat_from_ptr(b_ptr);
      const semiring = try semiring_from_code(semiring_code);
      const mask = mask_mat_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var nrows_a: u64 = undefined;
      var ncols_b: u64 = undefined;
      try translate_info(GrB_Matrix_nrows(&nrows_a, a));
      try translate_info(GrB_Matrix_ncols(&ncols_b, b));
      var a_type: GrB_Type = null;
      try translate_info(GxB_Matrix_type(&a_type, a));
      var result: GrB_Matrix = null;
      const info_new = GrB_Matrix_new(&result, a_type, nrows_a, ncols_b);
      try translate_info(info_new);
      const info = GrB_mxm(result, mask, null, semiring, a, b, desc);
      if (info != GrB_SUCCESS) {
          _ = GrB_Matrix_free(&result);
          try translate_info(info);
      }
      return mat_to_ptr(result);
  }

  pub fn matrix_mxv(matrix_ptr: usize, vector_ptr: usize, semiring_code: u8, mask_ptr: usize, desc_ptr: usize) !usize {
      const matrix = mat_from_ptr(matrix_ptr);
      const vector = vec_from_ptr(vector_ptr);
      const semiring = try semiring_from_code(semiring_code);
      const mask = mask_vec_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var nrows: u64 = undefined;
      try translate_info(GrB_Matrix_nrows(&nrows, matrix));
      var mat_type: GrB_Type = null;
      try translate_info(GxB_Matrix_type(&mat_type, matrix));
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, mat_type, nrows);
      try translate_info(info_new);
      const info = GrB_mxv(result, mask, null, semiring, matrix, vector, desc);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  pub fn matrix_transpose(ptr: usize, mask_ptr: usize, desc_ptr: usize) !usize {
      const matrix = mat_from_ptr(ptr);
      const mask = mask_mat_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var nrows: u64 = undefined;
      var ncols: u64 = undefined;
      try translate_info(GrB_Matrix_nrows(&nrows, matrix));
      try translate_info(GrB_Matrix_ncols(&ncols, matrix));
      var mat_type: GrB_Type = null;
      try translate_info(GxB_Matrix_type(&mat_type, matrix));
      var result: GrB_Matrix = null;
      const info_new = GrB_Matrix_new(&result, mat_type, ncols, nrows);
      try translate_info(info_new);
      const info = GrB_transpose(result, mask, null, matrix, desc);
      if (info != GrB_SUCCESS) {
          _ = GrB_Matrix_free(&result);
          try translate_info(info);
      }
      return mat_to_ptr(result);
  }

  pub fn matrix_ewise_add(a_ptr: usize, b_ptr: usize, monoid_code: u8, mask_ptr: usize, desc_ptr: usize) !usize {
      const a = mat_from_ptr(a_ptr);
      const b = mat_from_ptr(b_ptr);
      const monoid = try monoid_from_code(monoid_code);
      const mask = mask_mat_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var nrows: u64 = undefined;
      var ncols: u64 = undefined;
      try translate_info(GrB_Matrix_nrows(&nrows, a));
      try translate_info(GrB_Matrix_ncols(&ncols, a));
      var a_type: GrB_Type = null;
      try translate_info(GxB_Matrix_type(&a_type, a));
      var result: GrB_Matrix = null;
      const info_new = GrB_Matrix_new(&result, a_type, nrows, ncols);
      try translate_info(info_new);
      const info = GrB_Matrix_eWiseAdd_Monoid(result, mask, null, monoid, a, b, desc);
      if (info != GrB_SUCCESS) {
          _ = GrB_Matrix_free(&result);
          try translate_info(info);
      }
      return mat_to_ptr(result);
  }

  pub fn matrix_ewise_mult(a_ptr: usize, b_ptr: usize, monoid_code: u8, mask_ptr: usize, desc_ptr: usize) !usize {
      const a = mat_from_ptr(a_ptr);
      const b = mat_from_ptr(b_ptr);
      const monoid = try monoid_from_code(monoid_code);
      const mask = mask_mat_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var nrows: u64 = undefined;
      var ncols: u64 = undefined;
      try translate_info(GrB_Matrix_nrows(&nrows, a));
      try translate_info(GrB_Matrix_ncols(&ncols, a));
      var a_type: GrB_Type = null;
      try translate_info(GxB_Matrix_type(&a_type, a));
      var result: GrB_Matrix = null;
      const info_new = GrB_Matrix_new(&result, a_type, nrows, ncols);
      try translate_info(info_new);
      const info = GrB_Matrix_eWiseMult_Monoid(result, mask, null, monoid, a, b, desc);
      if (info != GrB_SUCCESS) {
          _ = GrB_Matrix_free(&result);
          try translate_info(info);
      }
      return mat_to_ptr(result);
  }

  pub fn matrix_reduce_to_vector(matrix_ptr: usize, monoid_code: u8, mask_ptr: usize, desc_ptr: usize) !usize {
      const matrix = mat_from_ptr(matrix_ptr);
      const monoid = try monoid_from_code(monoid_code);
      const mask = mask_vec_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var nrows: u64 = undefined;
      try translate_info(GrB_Matrix_nrows(&nrows, matrix));
      var mat_type: GrB_Type = null;
      try translate_info(GxB_Matrix_type(&mat_type, matrix));
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, mat_type, nrows);
      try translate_info(info_new);
      const info = GrB_Matrix_reduce_Monoid(result, mask, null, monoid, matrix, desc);
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
      const grb_type = try type_code_to_grb_type(type_code);
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

  pub fn vector_vxm(vector_ptr: usize, matrix_ptr: usize, semiring_code: u8, mask_ptr: usize, desc_ptr: usize) !usize {
      const vector = vec_from_ptr(vector_ptr);
      const matrix = mat_from_ptr(matrix_ptr);
      const semiring = try semiring_from_code(semiring_code);
      const mask = mask_vec_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var ncols: u64 = undefined;
      try translate_info(GrB_Matrix_ncols(&ncols, matrix));
      var vec_type: GrB_Type = null;
      try translate_info(GxB_Vector_type(&vec_type, vector));
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, vec_type, ncols);
      try translate_info(info_new);
      const info = GrB_vxm(result, mask, null, semiring, vector, matrix, desc);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  pub fn vector_ewise_add(a_ptr: usize, b_ptr: usize, monoid_code: u8, mask_ptr: usize, desc_ptr: usize) !usize {
      const a = vec_from_ptr(a_ptr);
      const b = vec_from_ptr(b_ptr);
      const monoid = try monoid_from_code(monoid_code);
      const mask = mask_vec_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var size: u64 = undefined;
      try translate_info(GrB_Vector_size(&size, a));
      var a_type: GrB_Type = null;
      try translate_info(GxB_Vector_type(&a_type, a));
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, a_type, size);
      try translate_info(info_new);
      const info = GrB_Vector_eWiseAdd_Monoid(result, mask, null, monoid, a, b, desc);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  pub fn vector_ewise_mult(a_ptr: usize, b_ptr: usize, monoid_code: u8, mask_ptr: usize, desc_ptr: usize) !usize {
      const a = vec_from_ptr(a_ptr);
      const b = vec_from_ptr(b_ptr);
      const monoid = try monoid_from_code(monoid_code);
      const mask = mask_vec_from_ptr(mask_ptr);
      const desc = desc_from_ptr(desc_ptr);
      var size: u64 = undefined;
      try translate_info(GrB_Vector_size(&size, a));
      var a_type: GrB_Type = null;
      try translate_info(GxB_Vector_type(&a_type, a));
      var result: GrB_Vector = null;
      const info_new = GrB_Vector_new(&result, a_type, size);
      try translate_info(info_new);
      const info = GrB_Vector_eWiseMult_Monoid(result, mask, null, monoid, a, b, desc);
      if (info != GrB_SUCCESS) {
          _ = GrB_Vector_free(&result);
          try translate_info(info);
      }
      return vec_to_ptr(result);
  }

  pub fn vector_reduce_to_scalar_int64(ptr: usize, monoid_code: u8) !i64 {
      const vector = vec_from_ptr(ptr);
      const monoid = try monoid_from_code(monoid_code);
      var result: i64 = 0;
      const info = GrB_Vector_reduce_INT64(&result, null, monoid, vector, null);
      try translate_info(info);
      return result;
  }

  pub fn vector_reduce_to_scalar_fp64(ptr: usize, monoid_code: u8) !f64 {
      const vector = vec_from_ptr(ptr);
      const monoid = try monoid_from_code(monoid_code);
      var result: f64 = 0.0;
      const info = GrB_Vector_reduce_FP64(&result, null, monoid, vector, null);
      try translate_info(info);
      return result;
  }

  pub fn vector_reduce_to_scalar_bool(ptr: usize, monoid_code: u8) !bool {
      const vector = vec_from_ptr(ptr);
      const monoid = try monoid_from_code(monoid_code);
      var result: bool = false;
      const info = GrB_Vector_reduce_BOOL(&result, null, monoid, vector, null);
      try translate_info(info);
      return result;
  }

  // =============================================================================
  // Descriptor management
  // =============================================================================

  fn resolve_descriptor(inp0_tran: bool, inp1_tran: bool, output_replace: bool, mask_comp: bool, mask_structural: bool) GrB_Descriptor {
      // Use pre-defined descriptor globals when possible for reliability.
      // Custom descriptors via GrB_Descriptor_set_INT32 fail for some mask
      // field values, so we map to the closest pre-defined global.
      if (output_replace) {
          if (mask_comp and mask_structural) {
              if (inp0_tran and inp1_tran) return GrB_DESC_RSCT0T1;
              if (inp0_tran) return GrB_DESC_RSCT0;
              if (inp1_tran) return GrB_DESC_RSCT1;
              return GrB_DESC_RSC;
          } else if (mask_structural) {
              if (inp0_tran and inp1_tran) return GrB_DESC_RST0T1;
              if (inp0_tran) return GrB_DESC_RST0;
              if (inp1_tran) return GrB_DESC_RST1;
              return GrB_DESC_RS;
          } else if (mask_comp) {
              // replace + complement valued mask: not a common pre-defined
              // fall through to custom descriptor below
          } else {
              if (inp0_tran and inp1_tran) return GrB_DESC_RT0T1;
              if (inp0_tran) return GrB_DESC_RT0;
              if (inp1_tran) return GrB_DESC_RT1;
              return GrB_DESC_R;
          }
      }
      if (mask_comp and mask_structural) {
          if (inp0_tran and inp1_tran) return GrB_DESC_SCT0T1;
          if (inp0_tran) return GrB_DESC_SCT0;
          if (inp1_tran) return GrB_DESC_SCT1;
          return GrB_DESC_SC;
      } else if (mask_structural) {
          if (inp0_tran and inp1_tran) return GrB_DESC_ST0T1;
          if (inp0_tran) return GrB_DESC_ST0;
          if (inp1_tran) return GrB_DESC_ST1;
          return GrB_DESC_S;
      } else if (mask_comp) {
          // complement valued mask without structural: not common
          // fall through to custom descriptor below
      } else {
          if (inp0_tran and inp1_tran) return GrB_DESC_T0T1;
          if (inp0_tran) return GrB_DESC_T0;
          if (inp1_tran) return GrB_DESC_T1;
      }
      return null;
  }

  pub fn descriptor_create(inp0_tran: bool, inp1_tran: bool, output_replace: bool, mask_comp: bool, mask_structural: bool) !usize {
      // Use pre-defined descriptor globals for common combinations.
      // These must not be freed via descriptor_free.
      const predefined = resolve_descriptor(inp0_tran, inp1_tran, output_replace, mask_comp, mask_structural);
      if (predefined != null) {
          return @intFromPtr(predefined);
      }

      // Fallback: create custom descriptor for uncommon combinations
      var desc: GrB_Descriptor = null;
      const info_new = GrB_Descriptor_new(&desc);
      try translate_info(info_new);

      if (desc == null) return error.null_pointer;

      if (output_replace) {
          try translate_info(GrB_Descriptor_set_INT32(desc, GrB_OUTP, GrB_REPLACE));
      }
      if (inp0_tran) {
          try translate_info(GrB_Descriptor_set_INT32(desc, GrB_INP0, GrB_TRAN));
      }
      if (inp1_tran) {
          try translate_info(GrB_Descriptor_set_INT32(desc, GrB_INP1, GrB_TRAN));
      }
      if (mask_comp and mask_structural) {
          try translate_info(GrB_Descriptor_set_INT32(desc, GrB_MASK, GrB_COMP_STRUCTURE));
      } else if (mask_comp) {
          try translate_info(GrB_Descriptor_set_INT32(desc, GrB_MASK, GrB_COMP));
      } else if (mask_structural) {
          try translate_info(GrB_Descriptor_set_INT32(desc, GrB_MASK, GrB_STRUCTURE));
      }

      return @intFromPtr(desc);
  }

  pub fn descriptor_is_custom(ptr: usize) bool {
      // Check if the ptr matches any pre-defined descriptor global.
      // If it does, it's not custom and should not be freed.
      const known_predefined = [_]usize{
          @intFromPtr(GrB_DESC_S),
          @intFromPtr(GrB_DESC_SC),
          @intFromPtr(GrB_DESC_T0),
          @intFromPtr(GrB_DESC_T1),
          @intFromPtr(GrB_DESC_T0T1),
          @intFromPtr(GrB_DESC_ST0),
          @intFromPtr(GrB_DESC_ST1),
          @intFromPtr(GrB_DESC_ST0T1),
          @intFromPtr(GrB_DESC_SCT0),
          @intFromPtr(GrB_DESC_SCT1),
          @intFromPtr(GrB_DESC_SCT0T1),
          @intFromPtr(GrB_DESC_R),
          @intFromPtr(GrB_DESC_RS),
          @intFromPtr(GrB_DESC_RSC),
          @intFromPtr(GrB_DESC_RT0),
          @intFromPtr(GrB_DESC_RT1),
          @intFromPtr(GrB_DESC_RT0T1),
          @intFromPtr(GrB_DESC_RST0),
          @intFromPtr(GrB_DESC_RST1),
          @intFromPtr(GrB_DESC_RST0T1),
          @intFromPtr(GrB_DESC_RSCT0),
          @intFromPtr(GrB_DESC_RSCT1),
          @intFromPtr(GrB_DESC_RSCT0T1),
      };
      for (known_predefined) |p| {
          if (ptr == p) return false;
      }
      return true;
  }

  pub fn descriptor_free(ptr: usize) void {
      if (ptr == 0) return;
      var desc: GrB_Descriptor = @ptrFromInt(ptr);
      _ = GrB_Descriptor_free(&desc);
  }

  // =============================================================================
  // Matrix set / extract / dup
  // =============================================================================

  pub fn matrix_set_int64(ptr: usize, row: u64, col: u64, val: i64) !void {
      const matrix = mat_from_ptr(ptr);
      const info = GrB_Matrix_setElement_INT64(matrix, val, row, col);
      try translate_info(info);
  }

  pub fn matrix_set_fp64(ptr: usize, row: u64, col: u64, val: f64) !void {
      const matrix = mat_from_ptr(ptr);
      const info = GrB_Matrix_setElement_FP64(matrix, val, row, col);
      try translate_info(info);
  }

  pub fn matrix_set_bool(ptr: usize, row: u64, col: u64, val: bool) !void {
      const matrix = mat_from_ptr(ptr);
      const info = GrB_Matrix_setElement_BOOL(matrix, val, row, col);
      try translate_info(info);
  }

  pub fn matrix_extract_int64(ptr: usize, row: u64, col: u64) !i64 {
      const matrix = mat_from_ptr(ptr);
      var val: i64 = 0;
      const info = GrB_Matrix_extractElement_INT64(&val, matrix, row, col);
      if (info == GrB_NO_VALUE) return 0;
      try translate_info(info);
      return val;
  }

  pub fn matrix_extract_fp64(ptr: usize, row: u64, col: u64) !f64 {
      const matrix = mat_from_ptr(ptr);
      var val: f64 = 0.0;
      const info = GrB_Matrix_extractElement_FP64(&val, matrix, row, col);
      if (info == GrB_NO_VALUE) return 0.0;
      try translate_info(info);
      return val;
  }

  pub fn matrix_extract_bool(ptr: usize, row: u64, col: u64) !bool {
      const matrix = mat_from_ptr(ptr);
      var val: bool = false;
      const info = GrB_Matrix_extractElement_BOOL(&val, matrix, row, col);
      if (info == GrB_NO_VALUE) return false;
      try translate_info(info);
      return val;
  }

  pub fn matrix_dup(ptr: usize) !usize {
      const source = mat_from_ptr(ptr);
      var copy: GrB_Matrix = null;
      const info = GrB_Matrix_dup(&copy, source);
      try translate_info(info);
      return mat_to_ptr(copy);
  }

  // =============================================================================
  // Vector set / extract / dup
  // =============================================================================

  pub fn vector_set_int64(ptr: usize, idx: u64, val: i64) !void {
      const vector = vec_from_ptr(ptr);
      const info = GrB_Vector_setElement_INT64(vector, val, idx);
      try translate_info(info);
  }

  pub fn vector_set_fp64(ptr: usize, idx: u64, val: f64) !void {
      const vector = vec_from_ptr(ptr);
      const info = GrB_Vector_setElement_FP64(vector, val, idx);
      try translate_info(info);
  }

  pub fn vector_set_bool(ptr: usize, idx: u64, val: bool) !void {
      const vector = vec_from_ptr(ptr);
      const info = GrB_Vector_setElement_BOOL(vector, val, idx);
      try translate_info(info);
  }

  pub fn vector_extract_int64(ptr: usize, idx: u64) !i64 {
      const vector = vec_from_ptr(ptr);
      var val: i64 = 0;
      const info = GrB_Vector_extractElement_INT64(&val, vector, idx);
      if (info == GrB_NO_VALUE) return 0;
      try translate_info(info);
      return val;
  }

  pub fn vector_extract_fp64(ptr: usize, idx: u64) !f64 {
      const vector = vec_from_ptr(ptr);
      var val: f64 = 0.0;
      const info = GrB_Vector_extractElement_FP64(&val, vector, idx);
      if (info == GrB_NO_VALUE) return 0.0;
      try translate_info(info);
      return val;
  }

  pub fn vector_extract_bool(ptr: usize, idx: u64) !bool {
      const vector = vec_from_ptr(ptr);
      var val: bool = false;
      const info = GrB_Vector_extractElement_BOOL(&val, vector, idx);
      if (info == GrB_NO_VALUE) return false;
      try translate_info(info);
      return val;
  }

  pub fn vector_dup(ptr: usize) !usize {
      const source = vec_from_ptr(ptr);
      var copy: GrB_Vector = null;
      const info = GrB_Vector_dup(&copy, source);
      try translate_info(info);
      return vec_to_ptr(copy);
  }
