# Phase 6 Benchmarks: Graph Algorithms - Elixir vs SuiteSparse
#
# Run with: mix run bench/phase6_algorithms_benchmarks.exs
#
# Benchmarks all Phase 6 algorithms on both backends:
#   - bfs_reach, bfs_levels, sssp, triangle_count, connected_components
#   - degree, pagerank, fixed_point
#   - Relation.traverse, Relation.closure

Application.ensure_all_started(:ex_graphblas)

alias GraphBLAS.Backend.Elixir, as: RefBackend
alias GraphBLAS.Backend.SuiteSparse
alias GraphBLAS.{Algorithm, BenchData, Matrix, Relation}

size_bfs = 100
chain_entries = BenchData.chain_graph(size_bfs)

{:ok, ref_bfs_chain} = RefBackend.matrix_from_coo(size_bfs, size_bfs, chain_entries, :bool, [])
{:ok, ss_bfs_chain} = SuiteSparse.matrix_from_coo(size_bfs, size_bfs, chain_entries, :bool, [])

IO.puts("\n=== bfs_reach (chain graph, #{size_bfs} vertices) ===\n")

Benchee.run(
  %{
    "elixir_bfs_reach" => fn ->
      {:ok, v} = Algorithm.bfs_reach(ref_bfs_chain, 0, backend: RefBackend)
      v
    end,
    "suitesparse_bfs_reach" => fn ->
      {:ok, v} = Algorithm.bfs_reach(ss_bfs_chain, 0, backend: SuiteSparse)
      v
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

size_levels = 200
rand_entries = BenchData.random_graph(size_levels, 0.05)

{:ok, ref_bfs_rand} =
  RefBackend.matrix_from_coo(size_levels, size_levels, rand_entries, :bool, [])

{:ok, ss_bfs_rand} =
  SuiteSparse.matrix_from_coo(size_levels, size_levels, rand_entries, :bool, [])

IO.puts("\n=== bfs_levels (random graph, #{size_levels} vertices, 5% density) ===\n")

Benchee.run(
  %{
    "elixir_bfs_levels" => fn ->
      {:ok, v} = Algorithm.bfs_levels(ref_bfs_rand, 0, backend: RefBackend)
      v
    end,
    "suitesparse_bfs_levels" => fn ->
      {:ok, v} = Algorithm.bfs_levels(ss_bfs_rand, 0, backend: SuiteSparse)
      v
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

size_sssp = 100
weighted_entries = BenchData.weighted_random_graph(size_sssp, 0.05)

{:ok, ref_sssp} = RefBackend.matrix_from_coo(size_sssp, size_sssp, weighted_entries, :fp64, [])
{:ok, ss_sssp} = SuiteSparse.matrix_from_coo(size_sssp, size_sssp, weighted_entries, :fp64, [])

IO.puts("\n=== sssp (weighted random graph, #{size_sssp} vertices, 5% density) ===\n")

Benchee.run(
  %{
    "elixir_sssp" => fn ->
      {:ok, v} = Algorithm.sssp(ref_sssp, 0, backend: RefBackend)
      v
    end,
    "suitesparse_sssp" => fn ->
      {:ok, v} = Algorithm.sssp(ss_sssp, 0, backend: SuiteSparse)
      v
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

size_tri = 100
undir_entries = BenchData.undirected_random_graph(size_tri, 0.10)

{:ok, ref_tri} = RefBackend.matrix_from_coo(size_tri, size_tri, undir_entries, :bool, [])
{:ok, ss_tri} = SuiteSparse.matrix_from_coo(size_tri, size_tri, undir_entries, :bool, [])

IO.puts("\n=== triangle_count (undirected random graph, #{size_tri} vertices, 10% density) ===\n")

Benchee.run(
  %{
    "elixir_triangle_count" => fn ->
      {:ok, _} = Algorithm.triangle_count(ref_tri, backend: RefBackend)
    end,
    "suitesparse_triangle_count" => fn ->
      {:ok, _} = Algorithm.triangle_count(ss_tri, backend: SuiteSparse)
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

size_cc = 100
cc_entries = BenchData.undirected_random_graph(size_cc, 0.05)

{:ok, ref_cc} = RefBackend.matrix_from_coo(size_cc, size_cc, cc_entries, :bool, [])
{:ok, ss_cc} = SuiteSparse.matrix_from_coo(size_cc, size_cc, cc_entries, :bool, [])

IO.puts(
  "\n=== connected_components (undirected random graph, #{size_cc} vertices, 5% density) ===\n"
)

Benchee.run(
  %{
    "elixir_connected_components" => fn ->
      {:ok, v} = Algorithm.connected_components(ref_cc, backend: RefBackend)
      v
    end,
    "suitesparse_connected_components" => fn ->
      {:ok, v} = Algorithm.connected_components(ss_cc, backend: SuiteSparse)
      v
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

size_deg = 500
star_entries = BenchData.star_graph(size_deg)

{:ok, ref_deg} = RefBackend.matrix_from_coo(size_deg, size_deg, star_entries, :bool, [])
{:ok, ss_deg} = SuiteSparse.matrix_from_coo(size_deg, size_deg, star_entries, :bool, [])

IO.puts("\n=== degree (star graph, #{size_deg} vertices) ===\n")

Benchee.run(
  %{
    "elixir_degree" => fn ->
      {:ok, _} = Algorithm.degree(ref_deg, backend: RefBackend)
    end,
    "suitesparse_degree" => fn ->
      {:ok, _} = Algorithm.degree(ss_deg, backend: SuiteSparse)
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

size_pr = 100
pr_entries = BenchData.random_graph(size_pr, 0.05)

{:ok, ref_pr} = RefBackend.matrix_from_coo(size_pr, size_pr, pr_entries, :bool, [])
{:ok, ss_pr} = SuiteSparse.matrix_from_coo(size_pr, size_pr, pr_entries, :bool, [])

IO.puts("\n=== pagerank (random graph, #{size_pr} vertices, 5% density) ===\n")

Benchee.run(
  %{
    "elixir_pagerank" => fn ->
      {:ok, v} = Algorithm.pagerank(ref_pr, backend: RefBackend, max_iter: 20)
      v
    end,
    "suitesparse_pagerank" => fn ->
      {:ok, v} = Algorithm.pagerank(ss_pr, backend: SuiteSparse, max_iter: 20)
      v
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

size_fp = 50
cycle_entries = BenchData.cycle_graph(size_fp)

{:ok, ref_fp} = RefBackend.matrix_from_coo(size_fp, size_fp, cycle_entries, :bool, [])
{:ok, ss_fp} = SuiteSparse.matrix_from_coo(size_fp, size_fp, cycle_entries, :bool, [])

IO.puts("\n=== fixed_point (cycle graph closure, #{size_fp} vertices) ===\n")

Benchee.run(
  %{
    "elixir_fixed_point" => fn ->
      {:ok, _result, _info} =
        Algorithm.fixed_point(
          ref_fp,
          fn p ->
            with {:ok, np} <- Matrix.mxm(p, ref_fp, :lor_land, backend: RefBackend),
                 {:ok, r} <- Matrix.ewise_add(p, np, :lor, backend: RefBackend) do
              {:ok, r}
            end
          end,
          max_iter: 10,
          backend: RefBackend
        )
    end,
    "suitesparse_fixed_point" => fn ->
      {:ok, _result, _info} =
        Algorithm.fixed_point(
          ss_fp,
          fn p ->
            with {:ok, np} <- Matrix.mxm(p, ss_fp, :lor_land, backend: SuiteSparse),
                 {:ok, r} <- Matrix.ewise_add(p, np, :lor, backend: SuiteSparse) do
              {:ok, r}
            end
          end,
          max_iter: 10,
          backend: SuiteSparse
        )
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

size_rel = 50
rel_density = 0.08

rel_entries_a = BenchData.random_graph(size_rel, rel_density)
rel_entries_b = BenchData.random_graph(size_rel, rel_density)
rel_entries_c = BenchData.random_graph(size_rel, rel_density)

rel_pairs_a = Enum.map(rel_entries_a, fn {s, o, _} -> {s, o} end)
rel_pairs_b = Enum.map(rel_entries_b, fn {s, o, _} -> {s, o} end)
rel_pairs_c = Enum.map(rel_entries_c, fn {s, o, _} -> {s, o} end)

ref_rel = Relation.new(size_rel)
{:ok, ref_rel} = Relation.add_triples(ref_rel, :follows, rel_pairs_a)
{:ok, ref_rel} = Relation.add_triples(ref_rel, :likes, rel_pairs_b)
{:ok, ref_rel} = Relation.add_triples(ref_rel, :knows, rel_pairs_c)

ss_rel = Relation.new(size_rel)
{:ok, ss_rel} = Relation.add_triples(ss_rel, :follows, rel_pairs_a)
{:ok, ss_rel} = Relation.add_triples(ss_rel, :likes, rel_pairs_b)
{:ok, ss_rel} = Relation.add_triples(ss_rel, :knows, rel_pairs_c)

IO.puts("\n=== Relation.traverse (3-hop, #{size_rel} vertices, 3 predicates) ===\n")

Benchee.run(
  %{
    "elixir_traverse_3hop" => fn ->
      {:ok, _} = Relation.traverse(ref_rel, [:follows, :likes, :knows], :lor_land)
    end,
    "suitesparse_traverse_3hop" => fn ->
      {:ok, _} = Relation.traverse(ss_rel, [:follows, :likes, :knows], :lor_land)
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

closure_entries = BenchData.random_graph(50, 0.08)
closure_pairs = Enum.map(closure_entries, fn {s, o, _} -> {s, o} end)

ref_closure_rel = Relation.new(50)
{:ok, ref_closure_rel} = Relation.add_triples(ref_closure_rel, :follows, closure_pairs)

ss_closure_rel = Relation.new(50)
{:ok, ss_closure_rel} = Relation.add_triples(ss_closure_rel, :follows, closure_pairs)

IO.puts("\n=== Relation.closure (transitive closure, 50 vertices) ===\n")

Benchee.run(
  %{
    "elixir_closure" => fn ->
      {:ok, _} = Relation.closure(ref_closure_rel, :follows, :lor_land)
    end,
    "suitesparse_closure" => fn ->
      {:ok, _} = Relation.closure(ss_closure_rel, :follows, :lor_land)
    end
  },
  time: 3,
  memory_time: 0,
  formatters: [{Benchee.Formatters.Console, comparison: false}]
)

SuiteSparse.matrix_free(ss_bfs_chain)
SuiteSparse.matrix_free(ss_bfs_rand)
SuiteSparse.matrix_free(ss_sssp)
SuiteSparse.matrix_free(ss_tri)
SuiteSparse.matrix_free(ss_cc)
SuiteSparse.matrix_free(ss_deg)
SuiteSparse.matrix_free(ss_pr)
SuiteSparse.matrix_free(ss_fp)
GraphBLAS.Native.grb_finalize()

IO.puts(
  "\n=====================================\nPhase 6 algorithm benchmarks complete.\n=====================================\n"
)
