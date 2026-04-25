defmodule GraphBLAS.AlgorithmTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.{Algorithm, Matrix, Vector}

  describe "bfs_reach/3" do
    test "reaches all vertices on a chain graph" do
      {:ok, adj} =
        Matrix.from_coo(5, 5, [{0, 1, true}, {1, 2, true}, {2, 3, true}, {3, 4, true}], :bool)

      {:ok, visited} = Algorithm.bfs_reach(adj, 0)
      {:ok, entries} = Vector.to_entries(visited)
      visited_indices = Enum.sort(Enum.map(entries, fn {i, _} -> i end))
      assert visited_indices == [0, 1, 2, 3, 4]
    end

    test "only reaches source when no out-edges" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, true}, {0, 2, true}], :bool)
      {:ok, visited} = Algorithm.bfs_reach(adj, 1)
      {:ok, entries} = Vector.to_entries(visited)
      visited_indices = Enum.sort(Enum.map(entries, fn {i, _} -> i end))
      assert visited_indices == [1]
    end

    test "visits only connected component on disconnected graph" do
      {:ok, adj} =
        Matrix.from_coo(
          6,
          6,
          [{0, 1, true}, {1, 0, true}, {2, 3, true}, {3, 2, true}],
          :bool
        )

      {:ok, visited} = Algorithm.bfs_reach(adj, 0)
      {:ok, entries} = Vector.to_entries(visited)
      visited_indices = Enum.sort(Enum.map(entries, fn {i, _} -> i end))
      assert visited_indices == [0, 1]
    end

    test "single vertex graph" do
      {:ok, adj} = Matrix.new(1, 1, :bool)
      {:ok, visited} = Algorithm.bfs_reach(adj, 0)
      {:ok, entries} = Vector.to_entries(visited)
      assert Enum.map(entries, fn {i, _} -> i end) == [0]
    end

    test "rejects out-of-bounds source" do
      {:ok, adj} = Matrix.from_coo(3, 3, [], :bool)
      assert {:error, _} = Algorithm.bfs_reach(adj, 5)
    end

    test "handles cycle without infinite loop" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, true}, {1, 2, true}, {2, 0, true}], :bool)
      {:ok, visited} = Algorithm.bfs_reach(adj, 0)
      {:ok, entries} = Vector.to_entries(visited)
      assert length(entries) == 3
    end
  end

  describe "bfs_levels/3" do
    test "computes correct hop distances on a chain" do
      {:ok, adj} =
        Matrix.from_coo(5, 5, [{0, 1, true}, {1, 2, true}, {2, 3, true}, {3, 4, true}], :bool)

      {:ok, levels} = Algorithm.bfs_levels(adj, 0)
      {:ok, entries} = Vector.to_entries(levels)
      level_map = Map.new(entries)
      assert level_map[0] == 0
      assert level_map[1] == 1
      assert level_map[2] == 2
      assert level_map[3] == 3
      assert level_map[4] == 4
    end

    test "level 0 for source only in star graph" do
      {:ok, adj} = Matrix.from_coo(4, 4, [{0, 1, true}, {0, 2, true}, {0, 3, true}], :bool)
      {:ok, levels} = Algorithm.bfs_levels(adj, 0)
      {:ok, entries} = Vector.to_entries(levels)
      level_map = Map.new(entries)
      assert level_map[0] == 0
      assert level_map[1] == 1
      assert level_map[2] == 1
      assert level_map[3] == 1
    end

    test "unvisited vertices absent in disconnected graph" do
      {:ok, adj} =
        Matrix.from_coo(
          6,
          6,
          [{0, 1, true}, {1, 0, true}, {2, 3, true}, {3, 2, true}],
          :bool
        )

      {:ok, levels} = Algorithm.bfs_levels(adj, 0)
      {:ok, entries} = Vector.to_entries(levels)
      level_map = Map.new(entries)
      indices = Enum.sort(Map.keys(level_map))
      assert indices == [0, 1]
    end
  end

  describe "sssp/3" do
    test "finds shortest paths on weighted chain" do
      {:ok, adj} =
        Matrix.from_coo(4, 4, [{0, 1, 1.0}, {1, 2, 1.0}, {2, 3, 1.0}, {0, 2, 5.0}], :fp64)

      {:ok, dist} = Algorithm.sssp(adj, 0)
      {:ok, entries} = Vector.to_entries(dist)
      dist_map = Map.new(entries)
      assert dist_map[0] == 0.0
      assert dist_map[1] == 1.0
      assert dist_map[2] == 2.0
      assert dist_map[3] == 3.0
    end

    test "source distance is zero" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, 3.0}, {1, 2, 2.0}], :fp64)
      {:ok, dist} = Algorithm.sssp(adj, 0)
      {:ok, entries} = Vector.to_entries(dist)
      dist_map = Map.new(entries)
      assert dist_map[0] == 0.0
      assert dist_map[1] == 3.0
      assert dist_map[2] == 5.0
    end

    test "unreachable vertices are absent" do
      {:ok, adj} = Matrix.from_coo(4, 4, [{0, 1, 1.0}], :fp64)
      {:ok, dist} = Algorithm.sssp(adj, 0)
      {:ok, entries} = Vector.to_entries(dist)
      dist_map = Map.new(entries)
      assert Map.has_key?(dist_map, 2) == false
      assert Map.has_key?(dist_map, 3) == false
    end

    test "handles varying edge weights" do
      {:ok, adj} =
        Matrix.from_coo(
          5,
          5,
          [
            {0, 1, 2.0},
            {0, 2, 10.0},
            {1, 2, 3.0},
            {1, 3, 7.0},
            {2, 3, 1.0},
            {3, 4, 2.0}
          ],
          :fp64
        )

      {:ok, dist} = Algorithm.sssp(adj, 0)
      {:ok, entries} = Vector.to_entries(dist)
      dist_map = Map.new(entries)
      assert dist_map[0] == 0.0
      assert dist_map[1] == 2.0
      assert dist_map[2] == 5.0
      assert dist_map[3] == 6.0
      assert dist_map[4] == 8.0
    end
  end

  describe "triangle_count/2" do
    test "counts triangles in K4 (complete graph on 4 vertices)" do
      edges =
        for i <- 0..3, j <- 0..3, i != j do
          {i, j, true}
        end

      {:ok, adj} = Matrix.from_coo(4, 4, edges, :bool)
      {:ok, count} = Algorithm.triangle_count(adj)
      assert count == 4
    end

    test "counts one triangle in a 3-cycle" do
      {:ok, adj} =
        Matrix.from_coo(
          3,
          3,
          [{0, 1, true}, {1, 0, true}, {1, 2, true}, {2, 1, true}, {0, 2, true}, {2, 0, true}],
          :bool
        )

      {:ok, count} = Algorithm.triangle_count(adj)
      assert count == 1
    end

    test "zero triangles in a chain" do
      {:ok, adj} =
        Matrix.from_coo(
          4,
          4,
          [{0, 1, true}, {1, 0, true}, {1, 2, true}, {2, 1, true}, {2, 3, true}, {3, 2, true}],
          :bool
        )

      {:ok, count} = Algorithm.triangle_count(adj)
      assert count == 0
    end

    test "zero triangles in empty graph" do
      {:ok, adj} = Matrix.from_coo(3, 3, [], :bool)
      {:ok, count} = Algorithm.triangle_count(adj)
      assert count == 0
    end
  end

  describe "pagerank/2" do
    test "computes pagerank on a simple graph" do
      {:ok, adj} =
        Matrix.from_coo(
          4,
          4,
          [
            {0, 1, true},
            {0, 2, true},
            {1, 2, true},
            {2, 0, true},
            {2, 3, true},
            {3, 2, true}
          ],
          :bool
        )

      {:ok, ranks} = Algorithm.pagerank(adj, max_iter: 50)
      {:ok, entries} = Vector.to_entries(ranks)
      rank_map = Map.new(entries)

      assert Map.has_key?(rank_map, 0)
      assert Map.has_key?(rank_map, 1)
      assert Map.has_key?(rank_map, 2)
      assert Map.has_key?(rank_map, 3)

      total = Enum.reduce(rank_map, 0.0, fn {_k, v}, acc -> acc + v end)
      assert abs(total - 1.0) < 0.01
    end

    test "pagerank on two-node mutual graph" do
      {:ok, adj} = Matrix.from_coo(2, 2, [{0, 1, true}, {1, 0, true}], :bool)
      {:ok, ranks} = Algorithm.pagerank(adj, max_iter: 50)
      {:ok, entries} = Vector.to_entries(ranks)
      rank_map = Map.new(entries)
      assert Map.has_key?(rank_map, 0)
      assert Map.has_key?(rank_map, 1)
      total = Enum.reduce(rank_map, 0.0, fn {_k, v}, acc -> acc + v end)
      assert abs(total - 1.0) < 0.01
    end
  end

  describe "connected_components/2" do
    test "single component in connected undirected graph" do
      {:ok, adj} =
        Matrix.from_coo(
          4,
          4,
          [{0, 1, true}, {1, 0, true}, {1, 2, true}, {2, 1, true}, {2, 3, true}, {3, 2, true}],
          :bool
        )

      {:ok, comp} = Algorithm.connected_components(adj)
      {:ok, entries} = Vector.to_entries(comp)
      comp_map = Map.new(entries)
      ids = Enum.uniq(Map.values(comp_map))
      assert length(ids) == 1
    end

    test "two components in disconnected graph" do
      {:ok, adj} =
        Matrix.from_coo(
          6,
          6,
          [{0, 1, true}, {1, 0, true}, {2, 3, true}, {3, 2, true}],
          :bool
        )

      {:ok, comp} = Algorithm.connected_components(adj)
      {:ok, entries} = Vector.to_entries(comp)
      comp_map = Map.new(entries)
      ids = Enum.uniq(Map.values(comp_map))
      assert length(ids) == 4
    end

    test "isolated vertices get own component" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, true}, {1, 0, true}], :bool)
      {:ok, comp} = Algorithm.connected_components(adj)
      {:ok, entries} = Vector.to_entries(comp)
      comp_map = Map.new(entries)
      assert Map.has_key?(comp_map, 0)
      assert Map.has_key?(comp_map, 1)
    end
  end

  describe "degree/2" do
    test "out-degree of star graph center" do
      {:ok, adj} =
        Matrix.from_coo(5, 5, [{0, 1, true}, {0, 2, true}, {0, 3, true}, {0, 4, true}], :bool)

      {:ok, %{out_degree: out_deg}} = Algorithm.degree(adj)
      {:ok, entries} = Vector.to_entries(out_deg)
      deg_map = Map.new(entries)
      assert deg_map[0] == 4
    end

    test "in-degree vector is computed" do
      {:ok, adj} =
        Matrix.from_coo(5, 5, [{0, 1, true}, {0, 2, true}, {0, 3, true}, {0, 4, true}], :bool)

      {:ok, %{in_degree: in_deg}} = Algorithm.degree(adj)
      {:ok, entries} = Vector.to_entries(in_deg)
      assert entries != []
    end
  end

  describe "fixed_point/3 (Phase 6C)" do
    test "converges and reports iteration count" do
      {:ok, adj} =
        Matrix.from_coo(3, 3, [{0, 1, true}, {1, 0, true}, {1, 2, true}, {2, 1, true}], :bool)

      {:ok, _result, info} =
        Algorithm.fixed_point(
          adj,
          fn p ->
            {:ok, new_paths} = Matrix.mxm(p, adj, :lor_land)
            {:ok, result} = Matrix.ewise_add(adj, new_paths, :lor)
            {:ok, result}
          end,
          max_iter: 10
        )

      assert info.converged == true
      assert info.iterations > 0
    end

    test "reports not converged when max_iter exceeded" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, true}, {1, 2, true}], :bool)

      {:ok, _result, info} =
        Algorithm.fixed_point(
          adj,
          fn p -> {:ok, p} end,
          max_iter: 0
        )

      assert info.converged == false
    end

    test "custom convergence function" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, true}], :bool)

      {:ok, _result, info} =
        Algorithm.fixed_point(
          adj,
          fn p -> {:ok, p} end,
          max_iter: 10,
          convergence_fn: fn _old, _new -> true end
        )

      assert info.converged == true
      assert info.iterations == 1
    end

    test "tolerance-based convergence with vectors" do
      {:ok, v} = Vector.from_entries(3, [{0, 1.0}, {1, 2.0}], :fp64)

      {:ok, _result, info} =
        Algorithm.fixed_point(
          v,
          fn p ->
            {:ok, entries} = Vector.to_entries(p)
            new_entries = Enum.map(entries, fn {i, val} -> {i, val * 0.99} end)
            Vector.from_entries(3, new_entries, :fp64)
          end,
          tol: 0.01,
          max_iter: 100
        )

      assert info.converged == true
    end

    test "exact convergence with vectors (tol = 0)" do
      {:ok, v} = Vector.from_entries(2, [{0, 5}, {1, 10}], :int64)

      {:ok, _result, info} =
        Algorithm.fixed_point(
          v,
          fn p -> {:ok, p} end,
          tol: 0,
          max_iter: 5
        )

      assert info.converged == true
      assert info.iterations == 1
    end

    test "default_converged with matrices" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64)

      {:ok, _result, info} =
        Algorithm.fixed_point(
          m,
          fn p -> {:ok, p} end,
          max_iter: 5
        )

      assert info.converged == true
      assert info.iterations == 1
    end

    test "default_converged with different container types across iterations" do
      {:ok, v} = Vector.from_entries(2, [{0, 1}], :int64)

      {:ok, result, info} =
        Algorithm.fixed_point(
          v,
          fn _p -> Matrix.from_coo(2, 2, [{0, 0, 1}], :int64) end,
          max_iter: 5
        )

      assert %Matrix{} = result
      assert info.iterations <= 5
    end
  end

  describe "pagerank/2 edge cases" do
    test "pagerank with max_iter limit reached (tests pagerank_loop max_iter guard)" do
      {:ok, adj} = Matrix.from_coo(2, 2, [{0, 1, true}, {1, 0, true}], :bool)
      {:ok, ranks} = Algorithm.pagerank(adj, max_iter: 2)
      {:ok, entries} = Vector.to_entries(ranks)
      assert length(entries) == 2
    end

    test "pagerank with custom damping factor" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, true}, {1, 2, true}, {2, 0, true}], :bool)
      {:ok, ranks} = Algorithm.pagerank(adj, damping: 0.5)
      {:ok, entries} = Vector.to_entries(ranks)
      rank_map = Map.new(entries)
      total = Enum.reduce(rank_map, 0.0, fn {_k, v}, acc -> acc + v end)
      assert abs(total - 1.0) < 0.01
    end

    test "pagerank with custom tolerance" do
      {:ok, adj} = Matrix.from_coo(2, 2, [{0, 1, true}, {1, 0, true}], :bool)
      {:ok, ranks} = Algorithm.pagerank(adj, tol: 0.1)
      {:ok, entries} = Vector.to_entries(ranks)
      assert length(entries) == 2
    end

    test "pagerank on graph with dangling nodes (tests apply_dangling_correction)" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, true}, {1, 2, true}], :bool)
      {:ok, ranks} = Algorithm.pagerank(adj, max_iter: 20)
      {:ok, entries} = Vector.to_entries(ranks)
      assert is_list(entries)
    end

    test "pagerank with zero damping (tests apply_shift with different shift values)" do
      {:ok, adj} = Matrix.from_coo(2, 2, [{0, 1, true}, {1, 0, true}], :bool)
      {:ok, ranks} = Algorithm.pagerank(adj, damping: 0.0, max_iter: 10)
      {:ok, entries} = Vector.to_entries(ranks)
      assert length(entries) == 2
    end
  end

  describe "degree/2 with fp64 adjacency (tests bool_to_int64 fp64 path)" do
    test "computes degree from fp64 weighted matrix" do
      {:ok, adj} = Matrix.from_coo(3, 3, [{0, 1, 2.5}, {0, 2, 1.5}, {1, 0, 3.0}], :fp64)
      {:ok, %{out_degree: out_deg, in_degree: in_deg}} = Algorithm.degree(adj)
      {:ok, out_entries} = Vector.to_entries(out_deg)
      {:ok, in_entries} = Vector.to_entries(in_deg)

      assert out_entries != []
      assert in_entries != []
    end
  end
end
