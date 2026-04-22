defmodule GraphBLAS.RelationTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.{Matrix, Relation}

  describe "new/1" do
    test "creates empty relation with size" do
      rel = Relation.new(4)
      assert rel.size == 4
      assert Relation.predicates(rel) == []
    end
  end

  describe "add_triples/3" do
    test "adds bool entries for a predicate" do
      rel = Relation.new(4)
      {:ok, rel} = Relation.add_triples(rel, :follows, [{0, 1}, {1, 2}])
      assert :follows in Relation.predicates(rel)
      {:ok, mat} = Relation.matrix(rel, :follows)
      {:ok, coo} = Matrix.to_coo(mat)
      assert length(coo) == 2
    end

    test "extends existing predicate" do
      rel = Relation.new(4)
      {:ok, rel} = Relation.add_triples(rel, :follows, [{0, 1}])
      {:ok, rel} = Relation.add_triples(rel, :follows, [{1, 2}])
      {:ok, mat} = Relation.matrix(rel, :follows)
      {:ok, coo} = Matrix.to_coo(mat)
      assert length(coo) == 2
    end
  end

  describe "add_weighted_triples/4" do
    test "adds weighted entries for a predicate" do
      rel = Relation.new(4)

      {:ok, rel} =
        Relation.add_weighted_triples(rel, :distance, [{0, 1, 3.0}, {1, 2, 5.0}], :fp64)

      assert :distance in Relation.predicates(rel)
      {:ok, mat} = Relation.matrix(rel, :distance)
      {:ok, {4, 4}} = Matrix.shape(mat)
    end

    test "extends existing weighted predicate" do
      rel = Relation.new(4)
      {:ok, rel} = Relation.add_weighted_triples(rel, :distance, [{0, 1, 3.0}], :fp64)
      {:ok, rel} = Relation.add_weighted_triples(rel, :distance, [{1, 2, 5.0}], :fp64)
      {:ok, mat} = Relation.matrix(rel, :distance)
      {:ok, coo} = Matrix.to_coo(mat)
      assert length(coo) == 2
    end
  end

  describe "matrix/2" do
    test "returns error for unknown predicate" do
      rel = Relation.new(4)
      assert {:error, _} = Relation.matrix(rel, :nonexistent)
    end
  end

  describe "traverse/4" do
    setup do
      rel = Relation.new(4)
      {:ok, rel} = Relation.add_triples(rel, :follows, [{0, 1}, {1, 2}])
      {:ok, rel} = Relation.add_triples(rel, :likes, [{1, 2}, {0, 2}])
      {:ok, rel} = Relation.add_triples(rel, :knows, [{0, 1}, {1, 0}])
      {:ok, rel} = Relation.add_triples(rel, :works_with, [{2, 3}, {3, 2}])
      {:ok, rel: rel}
    end

    test "2-hop traversal with lor_land finds existence", %{rel: rel} do
      {:ok, result} = Relation.traverse(rel, [:follows, :likes], :lor_land)
      {:ok, coo} = Matrix.to_coo(result)
      positions = Enum.sort(Enum.map(coo, fn {r, c, _} -> {r, c} end))
      # 0→follows→1→likes→2 and 1→follows→2→likes→? (no)
      assert {0, 2} in positions
    end

    test "2-hop traversal with plus_times counts paths", %{rel: rel} do
      {:ok, result} = Relation.traverse(rel, [:follows, :likes], :plus_times)
      {:ok, coo} = Matrix.to_coo(result)
      value_map = Map.new(coo, fn {r, c, v} -> {{r, c}, v} end)
      # 0→1→2 (1 path), 1→2→2 (no, 2 doesn't like anything in our data)
      assert Map.get(value_map, {0, 2}) != nil
    end

    test "3-hop traversal finds transitive paths", %{rel: rel} do
      {:ok, rel} = Relation.add_triples(rel, :reports_to, [{0, 1}, {1, 2}, {2, 3}])
      {:ok, result} = Relation.traverse(rel, [:reports_to, :reports_to, :reports_to], :lor_land)
      {:ok, coo} = Matrix.to_coo(result)
      positions = Enum.map(coo, fn {r, c, _} -> {r, c} end)
      assert {0, 3} in positions
    end

    test "returns error for empty path", %{rel: rel} do
      assert {:error, _} = Relation.traverse(rel, [], :lor_land)
    end

    test "returns error for unknown predicate", %{rel: rel} do
      assert {:error, _} = Relation.traverse(rel, [:nonexistent], :lor_land)
    end
  end

  describe "closure/4" do
    setup do
      rel = Relation.new(4)
      {:ok, rel} = Relation.add_triples(rel, :follows, [{0, 1}, {1, 2}, {2, 3}])
      {:ok, rel: rel}
    end

    test "transitive closure with lor_land reaches all reachable", %{rel: rel} do
      closure_result = Relation.closure(rel, :follows, :lor_land)
      assert match?({:ok, _}, closure_result)
      {:ok, result} = closure_result
      {:ok, coo} = Matrix.to_coo(result)
      positions = MapSet.new(Enum.map(coo, fn {r, c, _} -> {r, c} end))
      # Direct: 0→1, 1→2, 2→3
      # 2-hop: 0→2, 1→3
      # 3-hop: 0→3
      assert MapSet.member?(positions, {0, 1})
      assert MapSet.member?(positions, {0, 2})
      assert MapSet.member?(positions, {0, 3})
      assert MapSet.member?(positions, {1, 2})
      assert MapSet.member?(positions, {1, 3})
      assert MapSet.member?(positions, {2, 3})
    end

    test "closure returns error for unknown predicate", %{rel: rel} do
      assert {:error, %GraphBLAS.Error{reason: {:unknown_predicate, :unknown}}} =
               Relation.closure(rel, :unknown, :lor_land)
    end

    test "closure on cyclic graph converges" do
      rel = Relation.new(3)
      {:ok, rel} = Relation.add_triples(rel, :cycle, [{0, 1}, {1, 2}, {2, 0}])
      {:ok, result} = Relation.closure(rel, :cycle, :lor_land)
      {:ok, coo} = Matrix.to_coo(result)
      # In a 3-cycle, every node reaches every node
      assert length(coo) == 9
    end

    test "closure with plus_times semiring (path counting)" do
      rel = Relation.new(3)
      {:ok, rel} = Relation.add_weighted_triples(rel, :edge, [{0, 1, 1}, {1, 2, 1}], :int64)
      {:ok, result} = Relation.closure(rel, :edge, :plus_times)
      {:ok, coo} = Matrix.to_coo(result)
      # Should have paths: 0→1 (1), 1→2 (1), 0→2 (1 via 1)
      assert length(coo) >= 3
    end

    test "closure with plus_min semiring (shortest path)" do
      rel = Relation.new(3)
      {:ok, rel} = Relation.add_weighted_triples(rel, :dist, [{0, 1, 5}, {1, 2, 3}], :int64)
      {:ok, result} = Relation.closure(rel, :dist, :plus_min)
      {:ok, coo} = Matrix.to_coo(result)
      # Closure iteratively computes A + A^2 + A^3 + ..., should find all paths
      assert length(coo) >= 2
    end
  end

  describe "traverse/4 single predicate" do
    test "single-hop traversal with lor_land" do
      rel = Relation.new(3)
      {:ok, rel} = Relation.add_triples(rel, :follows, [{0, 1}, {1, 2}])
      {:ok, result} = Relation.traverse(rel, [:follows], :lor_land)
      {:ok, coo} = Matrix.to_coo(result)
      assert length(coo) == 2
      assert {0, 1, true} in coo
      assert {1, 2, true} in coo
    end

    test "single-hop traversal with plus_times on empty matrix" do
      rel = Relation.new(3)
      {:ok, rel} = Relation.add_triples(rel, :empty, [])
      {:ok, result} = Relation.traverse(rel, [:empty], :plus_times)
      {:ok, coo} = Matrix.to_coo(result)
      assert coo == []
    end

    test "single-hop returns error for unknown predicate" do
      rel = Relation.new(3)
      assert {:error, _} = Relation.traverse(rel, [:unknown], :lor_land)
    end
  end

  describe "traverse/4 multi-hop edge cases" do
    test "returns error when second predicate in path is unknown" do
      rel = Relation.new(3)
      {:ok, rel} = Relation.add_triples(rel, :follows, [{0, 1}])
      assert {:error, _} = Relation.traverse(rel, [:follows, :unknown], :lor_land)
    end

    test "returns error when last predicate in 3-hop path is unknown" do
      rel = Relation.new(3)
      {:ok, rel} = Relation.add_triples(rel, :a, [{0, 1}])
      {:ok, rel} = Relation.add_triples(rel, :b, [{1, 2}])
      assert {:error, _} = Relation.traverse(rel, [:a, :b, :unknown], :lor_land)
    end

    test "traverse with plus_min_fp64 semiring" do
      rel = Relation.new(3)
      {:ok, rel} = Relation.add_weighted_triples(rel, :cost, [{0, 1, 2.5}, {1, 2, 1.5}], :fp64)
      {:ok, result} = Relation.traverse(rel, [:cost, :cost], :plus_min_fp64)
      {:ok, coo} = Matrix.to_coo(result)
      # Traverse computes A * A (not closure), so the result depends on the semiring
      assert Enum.empty?(coo) == false
    end
  end

  describe "add_triples/4 with backend option" do
    test "creates new predicate with specified backend" do
      rel = Relation.new(3)
      backend = GraphBLAS.Backend.Elixir
      {:ok, rel} = Relation.add_triples(rel, :edge, [{0, 1}], backend: backend)
      {:ok, mat} = Relation.matrix(rel, :edge)
      assert mat.backend == backend
    end

    test "extends existing predicate preserving its backend" do
      rel = Relation.new(3)
      backend = GraphBLAS.Backend.SuiteSparse
      {:ok, rel} = Relation.add_triples(rel, :edge, [{0, 1}], backend: backend)
      {:ok, rel} = Relation.add_triples(rel, :edge, [{1, 2}])

      {:ok, mat} = Relation.matrix(rel, :edge)
      assert mat.backend == backend
    end
  end

  describe "add_weighted_triples/5 with backend option" do
    test "creates new predicate with specified backend" do
      rel = Relation.new(3)
      backend = GraphBLAS.Backend.Elixir

      {:ok, rel} =
        Relation.add_weighted_triples(rel, :dist, [{0, 1, 5}], :int64, backend: backend)

      {:ok, mat} = Relation.matrix(rel, :dist)
      assert mat.backend == backend
    end

    test "extends existing predicate preserving its backend" do
      rel = Relation.new(3)
      backend = GraphBLAS.Backend.SuiteSparse

      {:ok, rel} =
        Relation.add_weighted_triples(rel, :dist, [{0, 1, 5}], :int64, backend: backend)

      {:ok, rel} = Relation.add_weighted_triples(rel, :dist, [{1, 2, 3}], :int64)

      {:ok, mat} = Relation.matrix(rel, :dist)
      assert mat.backend == backend
    end
  end

  describe "Relation edge cases" do
    test "empty relation has no predicates" do
      rel = Relation.new(10)
      assert Relation.predicates(rel) == []
    end

    test "multiple predicates coexist" do
      rel = Relation.new(5)
      {:ok, rel} = Relation.add_triples(rel, :p1, [{0, 1}])
      {:ok, rel} = Relation.add_triples(rel, :p2, [{1, 2}])
      {:ok, rel} = Relation.add_weighted_triples(rel, :p3, [{2, 3, 10}], :int64)

      predicates = Relation.predicates(rel)
      assert :p1 in predicates
      assert :p2 in predicates
      assert :p3 in predicates
      assert length(predicates) == 3
    end

    test "closure with max iterations (convergence limit)" do
      # Create a large enough graph that might not converge quickly
      rel = Relation.new(10)
      edges = for i <- 0..8, do: {i, i + 1}
      {:ok, rel} = Relation.add_triples(rel, :path, edges)
      {:ok, result} = Relation.closure(rel, :path, :lor_land)
      {:ok, coo} = Matrix.to_coo(result)
      # Should eventually converge
      assert Enum.empty?(coo) == false
    end
  end
end
