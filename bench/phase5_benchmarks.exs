# Phase 5 Benchmarks: Masks, Descriptors, Set/Extract/Dup
#
# Run with: mix run bench/phase5_benchmarks.exs
#
# Benchmarks for the new Phase 5 functionality:
#   1. Masked mxm (structural vs complement) on both backends
#   2. Descriptor inp0_transpose on mxm on both backends
#   3. matrix_set / matrix_extract / matrix_dup on SuiteSparse
#   4. vector_set / vector_extract / vector_dup on SuiteSparse
#   5. Masked vs unmasked mxm overhead on SuiteSparse

Application.ensure_all_started(:ex_graphblas)

alias GraphBLAS.Backend.Elixir, as: RefBackend
alias GraphBLAS.Backend.SuiteSparse
alias GraphBLAS.{Mask, Descriptor, Matrix, Vector}

# --- Shared data ---

# 100x100 sparse matrix with ~10% density (~1000 entries)
density = 0.1
size = 100

large_entries =
  for r <- 0..(size - 1),
      c <- 0..(size - 1),
      :rand.uniform() < density do
    {r, c, :rand.uniform(100)}
  end

# Ensure at least some entries
large_entries = if large_entries == [], do: [{0, 0, 1}, {1, 1, 2}], else: large_entries

# 50x50 for descriptor transpose (non-square to show effect)
# A=50x80, A^T=80x50. B=50x40.
# mxm(A^T, B): ncols(A^T)=50 == nrows(B)=50 → 80x40 result. Works.
nrows_a = 50
ncols_a = 80
nrows_b = 50
ncols_b = 40

a_entries = for r <- 0..(nrows_a - 1), c <- 0..(ncols_a - 1), :rand.uniform() < 0.05, do: {r, c, :rand.uniform(50)}
b_entries = for r <- 0..(nrows_b - 1), c <- 0..(ncols_b - 1), :rand.uniform() < 0.05, do: {r, c, :rand.uniform(50)}
a_entries = if a_entries == [], do: [{0, 1, 1}], else: a_entries
b_entries = if b_entries == [], do: [{1, 0, 1}], else: b_entries

# Pre-build SuiteSparse matrices
{:ok, ss_m} = SuiteSparse.matrix_from_coo(size, size, large_entries, :int64, [])
{:ok, ss_a} = SuiteSparse.matrix_from_coo(nrows_a, ncols_a, a_entries, :int64, [])
{:ok, ss_b} = SuiteSparse.matrix_from_coo(nrows_b, ncols_b, b_entries, :int64, [])

# Pre-build reference matrices
{:ok, ref_m} = RefBackend.matrix_from_coo(size, size, large_entries, :int64, [])
{:ok, ref_a} = RefBackend.matrix_from_coo(nrows_a, ncols_a, a_entries, :int64, [])
{:ok, ref_b} = RefBackend.matrix_from_coo(nrows_b, ncols_b, b_entries, :int64, [])

# Mask: diagonal-only (structural mask that allows only diagonal positions)
mask_entries = for i <- 0..(size - 1), do: {i, i, 1}
{:ok, ss_mask_src} = SuiteSparse.matrix_from_coo(size, size, mask_entries, :int64, [])
{:ok, ref_mask_src} = RefBackend.matrix_from_coo(size, size, mask_entries, :int64, [])
ss_mask = Mask.new(ss_mask_src)
ref_mask = Mask.new(ref_mask_src)
ss_complement_mask = Mask.complement(ss_mask_src)
ref_complement_mask = Mask.complement(ref_mask_src)

# Vector for set/extract/dup
vec_entries = for i <- 0..(size - 1), :rand.uniform() < 0.1, do: {i, :rand.uniform(1000)}
vec_entries = if vec_entries == [], do: [{0, 1}, {5, 2}], else: vec_entries
{:ok, ss_v} = SuiteSparse.vector_from_entries(size, vec_entries, :int64, [])
{:ok, ref_v} = RefBackend.vector_from_entries(size, vec_entries, :int64, [])

# Small matrix for set/extract/dup
small_entries = for r <- 0..9, c <- 0..9, do: {r, c, r * 10 + c + 1}
{:ok, ss_small} = SuiteSparse.matrix_from_coo(10, 10, small_entries, :int64, [])
{:ok, ref_small} = RefBackend.matrix_from_coo(10, 10, small_entries, :int64, [])

# =============================================================================
# 1. Masked mxm: structural mask vs complement mask vs unmasked
# =============================================================================

IO.puts("\n=== Masked mxm (#{size}x#{size}, ~#{length(large_entries)} entries) ===\n")

Benchee.run(
  %{
    "ss_mxm_unmasked" => fn ->
      {:ok, c} = SuiteSparse.matrix_mxm(ss_m, ss_m, :plus_times, [])
      SuiteSparse.matrix_free(c)
    end,
    "ss_mxm_structural_mask" => fn ->
      {:ok, c} = SuiteSparse.matrix_mxm(ss_m, ss_m, :plus_times, mask: ss_mask)
      SuiteSparse.matrix_free(c)
    end,
    "ss_mxm_complement_mask" => fn ->
      {:ok, c} = SuiteSparse.matrix_mxm(ss_m, ss_m, :plus_times, mask: ss_complement_mask)
      SuiteSparse.matrix_free(c)
    end,
    "ref_mxm_unmasked" => fn ->
      {:ok, _} = RefBackend.matrix_mxm(ref_m, ref_m, :plus_times, [])
    end,
    "ref_mxm_structural_mask" => fn ->
      {:ok, _} = RefBackend.matrix_mxm(ref_m, ref_m, :plus_times, mask: ref_mask)
    end,
    "ref_mxm_complement_mask" => fn ->
      {:ok, _} = RefBackend.matrix_mxm(ref_m, ref_m, :plus_times, mask: ref_complement_mask)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

# =============================================================================
# 2. Descriptor inp0_transpose on mxm
# =============================================================================

IO.puts("\n=== Descriptor inp0_transpose on mxm (#{nrows_a}x#{ncols_a} * #{nrows_b}x#{ncols_b}) ===\n")

desc = Descriptor.new(inp0_transpose: :transpose)

Benchee.run(
  %{
    "ss_mxm_explicit_transpose" => fn ->
      {:ok, at} = SuiteSparse.matrix_transpose(ss_a, [])
      {:ok, c} = SuiteSparse.matrix_mxm(at, ss_b, :plus_times, [])
      SuiteSparse.matrix_free(at)
      SuiteSparse.matrix_free(c)
    end,
    "ss_mxm_descriptor_transpose" => fn ->
      {:ok, c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :plus_times, descriptor: desc)
      SuiteSparse.matrix_free(c)
    end,
    "ref_mxm_explicit_transpose" => fn ->
      {:ok, at} = RefBackend.matrix_transpose(ref_a, [])
      {:ok, _} = RefBackend.matrix_mxm(at, ref_b, :plus_times, [])
    end,
    "ref_mxm_descriptor_transpose" => fn ->
      {:ok, _} = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times, descriptor: desc)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

# =============================================================================
# 3. matrix_set / matrix_extract / matrix_dup
# =============================================================================

IO.puts("\n=== matrix_set / matrix_extract / matrix_dup (10x10) ===\n")

Benchee.run(
  %{
    "ss_matrix_set_int64" => fn ->
      {:ok, _} = SuiteSparse.matrix_set(ss_small, 5, 5, 999)
    end,
    "ss_matrix_extract_int64" => fn ->
      {:ok, _} = SuiteSparse.matrix_extract(ss_small, 5, 5)
    end,
    "ss_matrix_dup" => fn ->
      {:ok, copy} = SuiteSparse.matrix_dup(ss_small)
      SuiteSparse.matrix_free(copy)
    end,
    "ref_matrix_set_int64" => fn ->
      {:ok, _} = RefBackend.matrix_set(ref_small, 5, 5, 999)
    end,
    "ref_matrix_extract_int64" => fn ->
      {:ok, _} = RefBackend.matrix_extract(ref_small, 5, 5)
    end,
    "ref_matrix_dup" => fn ->
      {:ok, _} = RefBackend.matrix_dup(ref_small)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

# =============================================================================
# 4. vector_set / vector_extract / vector_dup
# =============================================================================

IO.puts("\n=== vector_set / vector_extract / vector_dup (size=#{size}) ===\n")

Benchee.run(
  %{
    "ss_vector_set_int64" => fn ->
      {:ok, _} = SuiteSparse.vector_set(ss_v, 10, 999)
    end,
    "ss_vector_extract_int64" => fn ->
      {:ok, _} = SuiteSparse.vector_extract(ss_v, 10)
    end,
    "ss_vector_dup" => fn ->
      {:ok, copy} = SuiteSparse.vector_dup(ss_v)
      SuiteSparse.vector_free(copy)
    end,
    "ref_vector_set_int64" => fn ->
      {:ok, _} = RefBackend.vector_set(ref_v, 10, 999)
    end,
    "ref_vector_extract_int64" => fn ->
      {:ok, _} = RefBackend.vector_extract(ref_v, 10)
    end,
    "ref_vector_dup" => fn ->
      {:ok, _} = RefBackend.vector_dup(ref_v)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

# =============================================================================
# 5. Masked vs unmasked mxm overhead on SuiteSparse (same data, different mask)
# =============================================================================

IO.puts("\n=== Mask overhead: unmasked vs masked mxm on SuiteSparse ===\n")

Benchee.run(
  %{
    "ss_mxm_no_mask" => fn ->
      {:ok, c} = SuiteSparse.matrix_mxm(ss_m, ss_m, :plus_times, [])
      SuiteSparse.matrix_free(c)
    end,
    "ss_mxm_with_mask" => fn ->
      {:ok, c} = SuiteSparse.matrix_mxm(ss_m, ss_m, :plus_times, mask: ss_mask)
      SuiteSparse.matrix_free(c)
    end,
    "ss_mxm_with_desc_mask" => fn ->
      desc = Descriptor.new(mask: :structural)
      {:ok, c} = SuiteSparse.matrix_mxm(ss_m, ss_m, :plus_times, mask: ss_mask, descriptor: desc)
      SuiteSparse.matrix_free(c)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

# --- Cleanup ---

SuiteSparse.matrix_free(ss_m)
SuiteSparse.matrix_free(ss_a)
SuiteSparse.matrix_free(ss_b)
SuiteSparse.matrix_free(ss_mask_src)
SuiteSparse.matrix_free(ss_small)
SuiteSparse.vector_free(ss_v)
GraphBLAS.Native.grb_finalize()

IO.puts("""

=====================================
Phase 5 benchmarks complete.
=====================================
""")
