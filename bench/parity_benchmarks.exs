# Parity Benchmarks: Elixir Reference Backend vs SuiteSparse Native Backend
#
# Run with: mix run bench/parity_benchmarks.exs
#
# These benchmarks compare the two backends on identical workloads.

Application.ensure_all_started(:ex_graphblas)

alias GraphBLAS.Backend.Elixir, as: RefBackend
alias GraphBLAS.Backend.SuiteSparse

small_entries = for r <- 0..9, c <- 0..9, do: {r, c, r * 10 + c + 1}

Benchee.run(
  %{
    "ref_backend_matrix_from_coo" => fn ->
      {:ok, m} = RefBackend.matrix_from_coo(10, 10, small_entries, :int64, [])
      m
    end,
    "ss_backend_matrix_from_coo" => fn ->
      {:ok, m} = SuiteSparse.matrix_from_coo(10, 10, small_entries, :int64, [])
      SuiteSparse.matrix_free(m)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

# Pre-build matrices for compute benchmarks
{:ok, ref_a} = RefBackend.matrix_from_coo(10, 10, small_entries, :int64, [])
{:ok, ss_a} = SuiteSparse.matrix_from_coo(10, 10, small_entries, :int64, [])

Benchee.run(
  %{
    "ref_backend_matrix_mxm" => fn ->
      {:ok, _} = RefBackend.matrix_mxm(ref_a, ref_a, :plus_times, [])
    end,
    "ss_backend_matrix_mxm" => fn ->
      {:ok, c} = SuiteSparse.matrix_mxm(ss_a, ss_a, :plus_times, [])
      SuiteSparse.matrix_free(c)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

Benchee.run(
  %{
    "ref_backend_matrix_transpose" => fn ->
      {:ok, _} = RefBackend.matrix_transpose(ref_a, [])
    end,
    "ss_backend_matrix_transpose" => fn ->
      {:ok, t} = SuiteSparse.matrix_transpose(ss_a, [])
      SuiteSparse.matrix_free(t)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

Benchee.run(
  %{
    "ref_backend_matrix_ewise_add" => fn ->
      {:ok, _} = RefBackend.matrix_ewise_add(ref_a, ref_a, :plus, [])
    end,
    "ss_backend_matrix_ewise_add" => fn ->
      {:ok, c} = SuiteSparse.matrix_ewise_add(ss_a, ss_a, :plus, [])
      SuiteSparse.matrix_free(c)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

Benchee.run(
  %{
    "ref_backend_matrix_reduce" => fn ->
      {:ok, _} = RefBackend.matrix_reduce(ref_a, :plus, [])
    end,
    "ss_backend_matrix_reduce" => fn ->
      {:ok, v} = SuiteSparse.matrix_reduce(ss_a, :plus, [])
      SuiteSparse.vector_free(v)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

# Vector benchmarks
vec_entries = for i <- 0..9, do: {i, i * 10 + 1}
{:ok, ref_v} = RefBackend.vector_from_entries(10, vec_entries, :int64, [])
{:ok, ss_v} = SuiteSparse.vector_from_entries(10, vec_entries, :int64, [])

Benchee.run(
  %{
    "ref_backend_vector_ewise_add" => fn ->
      {:ok, _} = RefBackend.vector_ewise_add(ref_v, ref_v, :plus, [])
    end,
    "ss_backend_vector_ewise_add" => fn ->
      {:ok, c} = SuiteSparse.vector_ewise_add(ss_v, ss_v, :plus, [])
      SuiteSparse.vector_free(c)
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

Benchee.run(
  %{
    "ref_backend_vector_reduce" => fn ->
      {:ok, _} = RefBackend.vector_reduce(ref_v, :plus, [])
    end,
    "ss_backend_vector_reduce" => fn ->
      {:ok, _} = SuiteSparse.vector_reduce(ss_v, :plus, [])
    end
  },
  time: 2,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

# Cleanup
SuiteSparse.matrix_free(ss_a)
SuiteSparse.vector_free(ss_v)
GraphBLAS.Native.grb_finalize()

IO.puts("""

=====================================
Benchmarks complete.
=====================================
""")

IO.puts("""

=====================================
Benchmarks complete.
=====================================
""")
