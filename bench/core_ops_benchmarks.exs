# Core Operations Benchmarks: Elixir vs SuiteSparse
#
# Run with: mix run bench/core_ops_benchmarks.exs
#
# Benchmarks core sparse operations at multiple sizes and densities.

Application.ensure_all_started(:ex_graphblas)

alias GraphBLAS.Backend.Elixir, as: RefBackend
alias GraphBLAS.Backend.SuiteSparse
alias GraphBLAS.{Matrix, Vector}

benchee_opts = [
  time: 2,
  memory_time: 1,
  warmup: 1,
  formatters: [{Benchee.Formatters.Console, comparison: true}]
]

# --- from_coo construction ---

IO.puts("\n=== from_coo (100x100, 5% density, :int64) ===")

entries_100_5pct =
  Enum.flat_map(0..99, fn r ->
    Enum.flat_map(0..99, fn c ->
      if :rand.uniform() < 0.05, do: [{r, c, :rand.uniform(100)}], else: []
    end)
  end)

Benchee.run(
  %{
    "elixir_from_coo" => fn ->
      {:ok, m} = Matrix.from_coo(100, 100, entries_100_5pct, :int64, backend: RefBackend)
      m
    end,
    "suitesparse_from_coo" => fn ->
      {:ok, m} = Matrix.from_coo(100, 100, entries_100_5pct, :int64, backend: SuiteSparse)
      SuiteSparse.matrix_free(m)
    end
  },
  benchee_opts
)

IO.puts("\n=== from_coo (500x500, 10% density, :int64) ===")

entries_500_10pct =
  Enum.flat_map(0..499, fn r ->
    Enum.flat_map(0..499, fn c ->
      if :rand.uniform() < 0.10, do: [{r, c, :rand.uniform(100)}], else: []
    end)
  end)

Benchee.run(
  %{
    "elixir_from_coo" => fn ->
      {:ok, m} = Matrix.from_coo(500, 500, entries_500_10pct, :int64, backend: RefBackend)
      m
    end,
    "suitesparse_from_coo" => fn ->
      {:ok, m} = Matrix.from_coo(500, 500, entries_500_10pct, :int64, backend: SuiteSparse)
      SuiteSparse.matrix_free(m)
    end
  },
  benchee_opts
)

# --- Pre-build matrices for compute benchmarks ---

{:ok, m100_elixir} = Matrix.from_coo(100, 100, entries_100_5pct, :int64, backend: RefBackend)
{:ok, m100_ss} = Matrix.from_coo(100, 100, entries_100_5pct, :int64, backend: SuiteSparse)

entries_100_5pct_v2 =
  Enum.flat_map(0..99, fn r ->
    Enum.flat_map(0..99, fn c ->
      if :rand.uniform() < 0.05, do: [{r, c, :rand.uniform(100)}], else: []
    end)
  end)

{:ok, m100b_elixir} = Matrix.from_coo(100, 100, entries_100_5pct_v2, :int64, backend: RefBackend)
{:ok, m100b_ss} = Matrix.from_coo(100, 100, entries_100_5pct_v2, :int64, backend: SuiteSparse)

# --- mxm ---

IO.puts("\n=== mxm (100x100 * 100x100, :plus_times) ===")

Benchee.run(
  %{
    "elixir_mxm" => fn ->
      {:ok, _} = Matrix.mxm(m100_elixir, m100b_elixir, :plus_times, backend: RefBackend)
    end,
    "suitesparse_mxm" => fn ->
      {:ok, r} = Matrix.mxm(m100_ss, m100b_ss, :plus_times, backend: SuiteSparse)
      SuiteSparse.matrix_free(r)
    end
  },
  benchee_opts
)

# --- ewise_add ---

IO.puts("\n=== ewise_add (100x100, :plus) ===")

Benchee.run(
  %{
    "elixir_ewise_add" => fn ->
      {:ok, _} = Matrix.ewise_add(m100_elixir, m100b_elixir, :plus, backend: RefBackend)
    end,
    "suitesparse_ewise_add" => fn ->
      {:ok, r} = Matrix.ewise_add(m100_ss, m100b_ss, :plus, backend: SuiteSparse)
      SuiteSparse.matrix_free(r)
    end
  },
  benchee_opts
)

# --- ewise_mult ---

IO.puts("\n=== ewise_mult (100x100, :times) ===")

Benchee.run(
  %{
    "elixir_ewise_mult" => fn ->
      {:ok, _} = Matrix.ewise_mult(m100_elixir, m100b_elixir, :times, backend: RefBackend)
    end,
    "suitesparse_ewise_mult" => fn ->
      {:ok, r} = Matrix.ewise_mult(m100_ss, m100b_ss, :times, backend: SuiteSparse)
      SuiteSparse.matrix_free(r)
    end
  },
  benchee_opts
)

# --- reduce ---

IO.puts("\n=== reduce (100x100, :plus) ===")

Benchee.run(
  %{
    "elixir_reduce" => fn ->
      {:ok, _} = Matrix.reduce(m100_elixir, :plus, backend: RefBackend)
    end,
    "suitesparse_reduce" => fn ->
      {:ok, r} = Matrix.reduce(m100_ss, :plus, backend: SuiteSparse)
      SuiteSparse.vector_free(r)
    end
  },
  benchee_opts
)

# --- transpose ---

IO.puts("\n=== transpose (100x100) ===")

Benchee.run(
  %{
    "elixir_transpose" => fn ->
      {:ok, _} = Matrix.transpose(m100_elixir, backend: RefBackend)
    end,
    "suitesparse_transpose" => fn ->
      {:ok, r} = Matrix.transpose(m100_ss, backend: SuiteSparse)
      SuiteSparse.matrix_free(r)
    end
  },
  benchee_opts
)

# --- mxv ---

{:ok, v100_elixir} = Vector.from_entries(100, Enum.map(0..99, fn i -> {i, :rand.uniform(10)} end), :int64, backend: RefBackend)
{:ok, v100_ss} = Vector.from_entries(100, Enum.map(0..99, fn i -> {i, :rand.uniform(10)} end), :int64, backend: SuiteSparse)

IO.puts("\n=== mxv (100x100 * 100, :plus_times) ===")

Benchee.run(
  %{
    "elixir_mxv" => fn ->
      {:ok, _} = Matrix.mxv(m100_elixir, v100_elixir, :plus_times, backend: RefBackend)
    end,
    "suitesparse_mxv" => fn ->
      {:ok, r} = Matrix.mxv(m100_ss, v100_ss, :plus_times, backend: SuiteSparse)
      SuiteSparse.vector_free(r)
    end
  },
  benchee_opts
)

# --- vxm ---

IO.puts("\n=== vxm (100 * 100x100, :plus_times) ===")

Benchee.run(
  %{
    "elixir_vxm" => fn ->
      {:ok, _} = Vector.vxm(v100_elixir, m100_elixir, :plus_times, backend: RefBackend)
    end,
    "suitesparse_vxm" => fn ->
      {:ok, r} = Vector.vxm(v100_ss, m100_ss, :plus_times, backend: SuiteSparse)
      SuiteSparse.vector_free(r)
    end
  },
  benchee_opts
)

# --- Cleanup ---

SuiteSparse.matrix_free(m100_ss)
SuiteSparse.matrix_free(m100b_ss)
SuiteSparse.vector_free(v100_ss)
