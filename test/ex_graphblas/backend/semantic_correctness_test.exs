defmodule GraphBLAS.Backend.SemanticCorrectnessTest do
  @moduledoc """
  Tier 2 semantic correctness tests for the Elixir backend.

  Each test states the mathematical operation being tested, shows the
  expected result computed by hand, and verifies the backend produces
  the exact same result. These tests serve as the authoritative oracle
  for future backend parity validation.
  """
  use ExUnit.Case, async: true

  alias GraphBLAS.{Matrix, Vector, Scalar}
  alias GraphBLAS.Backend.Elixir, as: RefBackend

  #############################################################################
  # Matrix construction from COO
  #############################################################################

  describe "matrix construction (semantic)" do
    test "identity matrix produces correct COO output" do
      # 3x3 identity: diag(1,1,1)
      # Expected: Entries at (0,0)=1, (1,1)=1, (2,2)=1
      entries = [{0, 0, 1}, {1, 1, 1}, {2, 2, 1}]
      assert {:ok, m} = RefBackend.matrix_from_coo(3, 3, entries, :int64, [])
      assert {:ok, {3, 3}} = Matrix.shape(m)
      assert {:ok, 3} = Matrix.nvals(m)
      assert {:ok, coo} = Matrix.to_coo(m)
      assert coo == [{0, 0, 1}, {1, 1, 1}, {2, 2, 1}]
    end

    test "duplicate entries are combined with additive monoid" do
      # Two entries at (0,0) with values 3 and 7
      # Expected: (0,0) = 3+7 = 10
      entries = [{0, 0, 3}, {0, 0, 7}]
      assert {:ok, m} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
      assert {:ok, [{0, 0, 10}]} = Matrix.to_coo(m)
    end

    test "empty matrix has zero stored values" do
      assert {:ok, m} = RefBackend.matrix_new(5, 5, :int64, [])
      assert {:ok, 0} = Matrix.nvals(m)
      assert {:ok, {5, 5}} = Matrix.shape(m)
    end
  end

  #############################################################################
  # mxm with plus_times semiring
  #############################################################################

  describe "mxm with plus_times semiring (semantic)" do
    test "2x3 times 3x2 matrix multiplication" do
      # A = [[0,1,2],    B = [[1,0],
      #      [3,0,0]]         [0,4],
      #                       [5,0]]
      #
      # C = A * B = plus_times
      # C(0,0) = 0*1 + 1*0 + 2*5 = 10
      # C(0,1) = 0*0 + 1*4 + 2*0 = 4
      # C(1,0) = 3*1 + 0*0 + 0*5 = 3
      # C(1,1) = 3*0 + 0*4 + 0*0 = 0  (structural zero, omitted)
      entries_a = [{0, 1, 1}, {0, 2, 2}, {1, 0, 3}]
      entries_b = [{0, 0, 1}, {1, 1, 4}, {2, 0, 5}]

      assert {:ok, a} = RefBackend.matrix_from_coo(2, 3, entries_a, :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(3, 2, entries_b, :int64, [])
      assert {:ok, c} = RefBackend.matrix_mxm(a, b, :plus_times, [])

      assert {:ok, {2, 2}} = Matrix.shape(c)
      assert {:ok, coo} = Matrix.to_coo(c)
      # C should have: (0,0)=10, (0,1)=4, (1,0)=3
      assert Enum.sort(coo) == [{0, 0, 10}, {0, 1, 4}, {1, 0, 3}]
    end

    test "identity times identity equals identity (plus_times)" do
      # I * I = I with plus_times semiring
      entries_i = [{0, 0, 1}, {1, 1, 1}, {2, 2, 1}]
      assert {:ok, i} = RefBackend.matrix_from_coo(3, 3, entries_i, :int64, [])
      assert {:ok, result} = RefBackend.matrix_mxm(i, i, :plus_times, [])

      assert {:ok, coo} = Matrix.to_coo(result)
      assert Enum.sort(coo) == [{0, 0, 1}, {1, 1, 1}, {2, 2, 1}]
    end

    test "zero matrix times anything yields zero (empty result)" do
      # Empty matrix A(2x2) times non-empty B(2x2) should yield empty
      assert {:ok, a} = RefBackend.matrix_new(2, 2, :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 5}], :int64, [])
      assert {:ok, c} = RefBackend.matrix_mxm(a, b, :plus_times, [])
      assert {:ok, 0} = Matrix.nvals(c)
    end
  end

  #############################################################################
  # mxm with lor_land semiring (boolean adjacency / BFS reachability)
  #############################################################################

  describe "mxm with lor_land semiring (semantic)" do
    test "boolean adjacency: 1-hop reachability" do
      # Graph: 0 -> 1 -> 2
      # Adjacency matrix A:
      #   A(0,1)=true, A(1,2)=true
      #
      # A * A (lor_land):
      # C(i,j) = lor over k of (A(i,k) land A(k,j))
      # C(0,2) = A(0,1) land A(1,2) = true land true = true
      # All other products are false
      entries_a = [{0, 1, true}, {1, 2, true}]
      assert {:ok, a} = RefBackend.matrix_from_coo(3, 3, entries_a, :bool, [])

      assert {:ok, c} = RefBackend.matrix_mxm(a, a, :lor_land, [])
      assert {:ok, coo} = Matrix.to_coo(c)
      # Only (0,2) should be true
      assert Enum.sort(coo) == [{0, 2, true}]
    end

    test "boolean identity with lor_land" do
      # Boolean identity: diag(true, true, true)
      # I_lor_land * I_lor_land should equal I_lor_land
      entries_i = [{0, 0, true}, {1, 1, true}, {2, 2, true}]
      assert {:ok, i} = RefBackend.matrix_from_coo(3, 3, entries_i, :bool, [])

      assert {:ok, result} = RefBackend.matrix_mxm(i, i, :lor_land, [])
      assert {:ok, coo} = Matrix.to_coo(result)
      assert Enum.sort(coo) == [{0, 0, true}, {1, 1, true}, {2, 2, true}]
    end
  end

  #############################################################################
  # mxm with min_plus semiring (shortest path)
  #############################################################################

  describe "mxm with plus_min semiring (semantic)" do
    test "plus_min: add=min-aggregates, multiply=min-pairwise" do
      # plus_min semiring: multiply=min, add=plus
      # C(i,j) = sum over k of min(A(i,k), B(k,j))
      #
      # A = [[0,3,7],
      #       [0,0,5],
      #       [0,0,0]]  (sparse: only entries at (0,1)=3, (0,2)=7, (1,2)=5)
      #
      # A*A with plus_min:
      # C(0,2): matching k where both A(0,k) and A(k,2) stored:
      #   k=1: min(A(0,1), A(1,2)) = min(3, 5) = 3
      #   (k=2: A(0,2)=7 but A(2,j) has no stored entries -> no match)
      # C(0,2) = 3
      entries_a = [{0, 1, 3}, {0, 2, 7}, {1, 2, 5}]
      assert {:ok, a} = RefBackend.matrix_from_coo(3, 3, entries_a, :int64, [])

      assert {:ok, c} = RefBackend.matrix_mxm(a, a, :plus_min, [])
      assert {:ok, coo} = Matrix.to_coo(c)
      assert {0, 2, 3} in coo
    end
  end

  #############################################################################
  # mxv (matrix-vector multiplication)
  #############################################################################

  describe "mxv (semantic)" do
    test "matrix times vector with plus_times" do
      # A = [[1,2],[3,4]], x = [5, 6]^T
      # A*x = [1*5+2*6, 3*5+4*6] = [17, 39]
      entries_a = [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}, {1, 1, 4}]
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 2, entries_a, :int64, [])
      assert {:ok, v} = RefBackend.vector_from_entries(2, [{0, 5}, {1, 6}], :int64, [])

      assert {:ok, result} = RefBackend.matrix_mxv(a, v, :plus_times, [])
      assert {:ok, entries} = Vector.to_entries(result)
      assert Enum.sort(entries) == [{0, 17}, {1, 39}]
    end

    test "mxv with sparse matrix and sparse vector" do
      # A(2,3) = [[0,1,0],[0,0,2]]
      # x = [0, 3, 0]^T  (only index 1 is nonzero)
      # A*x = [1*3, 0] = [3, 0]
      # But (1,*): row 1 = [0,0,2], x = [0,3,0]
      # (1,0)*x(0) + (1,1)*x(1) + (1,2)*x(2) = 0*0 + 0*3 + 2*0 = 0
      # Actually: sparse semantics. Only stored entries count.
      # Row 0: A(0,1)*x(1) = 1*3 = 3  => result(0) = 3
      # Row 1: A(1,2)*x(2) = ??? but x only has entry at index 1, not 2
      # So row 1 has no matching k where both A(1,k) and x(k) are stored
      entries_a = [{0, 1, 1}, {1, 2, 2}]
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 3, entries_a, :int64, [])
      assert {:ok, v} = RefBackend.vector_from_entries(3, [{1, 3}], :int64, [])

      assert {:ok, result} = RefBackend.matrix_mxv(a, v, :plus_times, [])
      # Only row 0 produces a nonzero result: 1*3 = 3
      assert {:ok, entries} = Vector.to_entries(result)
      assert Enum.sort(entries) == [{0, 3}]
    end
  end

  #############################################################################
  # vxm (vector-matrix multiplication)
  #############################################################################

  describe "vxm (semantic)" do
    test "vector times matrix with plus_times" do
      # x = [2, 3]^T  (row vector * matrix): x^T * A
      # A = [[1,0],[0,4]]
      # x^T * A = [2*1, 3*4] = [2, 12]
      entries_a = [{0, 0, 1}, {1, 1, 4}]
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 2, entries_a, :int64, [])
      assert {:ok, v} = RefBackend.vector_from_entries(2, [{0, 2}, {1, 3}], :int64, [])

      assert {:ok, result} = RefBackend.vector_vxm(v, a, :plus_times, [])
      assert {:ok, entries} = Vector.to_entries(result)
      assert Enum.sort(entries) == [{0, 2}, {1, 12}]
    end
  end

  #############################################################################
  # ewise_add and ewise_mult (semantic)
  #############################################################################

  describe "ewise_add (semantic - union)" do
    test "union of positions: overlapping summed, disjoint carried" do
      # A has (0,0)=1, (1,1)=2
      # B has (0,0)=3, (0,1)=4
      # ewise_add with :plus:
      #   (0,0) = 1+3 = 4 (overlapping)
      #   (0,1) = 4 (from B only)
      #   (1,1) = 2 (from A only)
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 3}, {0, 1, 4}], :int64, [])

      assert {:ok, c} = RefBackend.matrix_ewise_add(a, b, :plus, [])
      assert {:ok, 3} = Matrix.nvals(c)
      assert {:ok, coo} = Matrix.to_coo(c)
      assert {0, 0, 4} in coo
      assert {0, 1, 4} in coo
      assert {1, 1, 2} in coo
    end

    test "ewise_add with :max monoid" do
      # A has (0,0)=5
      # B has (0,0)=3
      # max(5, 3) = 5
      assert {:ok, a} = RefBackend.matrix_from_coo(1, 1, [{0, 0, 5}], :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(1, 1, [{0, 0, 3}], :int64, [])

      assert {:ok, c} = RefBackend.matrix_ewise_add(a, b, :max, [])
      assert {:ok, [{0, 0, 5}]} = Matrix.to_coo(c)
    end
  end

  describe "ewise_mult (semantic - intersection)" do
    test "intersection: only overlapping positions kept" do
      # A has (0,0)=2, (0,1)=3
      # B has (0,0)=4, (1,0)=5
      # ewise_mult with :times:
      #   (0,0) = 2*4 = 8 (overlapping)
      #   (0,1) from A only -> dropped
      #   (1,0) from B only -> dropped
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 2}, {0, 1, 3}], :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 4}, {1, 0, 5}], :int64, [])

      assert {:ok, c} = RefBackend.matrix_ewise_mult(a, b, :times, [])
      assert {:ok, 1} = Matrix.nvals(c)
      assert {:ok, [{0, 0, 8}]} = Matrix.to_coo(c)
    end

    test "ewise_mult with disjoint matrices yields empty" do
      # A has (0,0)=1, B has (1,1)=2. No overlap.
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{1, 1, 2}], :int64, [])

      assert {:ok, c} = RefBackend.matrix_ewise_mult(a, b, :times, [])
      assert {:ok, 0} = Matrix.nvals(c)
    end
  end

  #############################################################################
  # reduce (semantic)
  #############################################################################

  describe "reduce (semantic)" do
    test "row reduction with :plus monoid" do
      # A = [[1,2,0],
      #      [3,0,4]]
      # Reduce columns per row with plus:
      # Row 0: 1+2 = 3
      # Row 1: 3+4 = 7
      # Result vector: [3, 7]
      entries = [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}, {1, 2, 4}]
      assert {:ok, m} = RefBackend.matrix_from_coo(2, 3, entries, :int64, [])

      assert {:ok, v} = RefBackend.matrix_reduce(m, :plus, [])
      assert {:ok, result} = Vector.to_entries(v)
      assert Enum.sort(result) == [{0, 3}, {1, 7}]
    end

    test "row reduction with :max monoid" do
      # A = [[1,5,3],
      #      [2,0,7]]
      # Max per row:
      # Row 0: max(1,5,3) = 5
      # Row 1: max(2,7) = 7
      entries = [{0, 0, 1}, {0, 1, 5}, {0, 2, 3}, {1, 0, 2}, {1, 2, 7}]
      assert {:ok, m} = RefBackend.matrix_from_coo(2, 3, entries, :int64, [])

      assert {:ok, v} = RefBackend.matrix_reduce(m, :max, [])
      assert {:ok, result} = Vector.to_entries(v)
      assert {0, 5} in result
      assert {1, 7} in result
    end

    test "vector reduce to scalar with :plus" do
      # v = [10, 20, 30]
      # plus reduction = 60
      assert {:ok, v} = RefBackend.vector_from_entries(3, [{0, 10}, {1, 20}, {2, 30}], :int64, [])
      assert {:ok, scalar} = RefBackend.vector_reduce(v, :plus, [])
      assert %Scalar{type: :int64, value: 60} = scalar
    end
  end

  #############################################################################
  # transpose (semantic)
  #############################################################################

  describe "transpose (semantic)" do
    test "transpose of non-square matrix" do
      # A is 2x3:
      #   [[0, 1, 2],
      #    [3, 0, 0]]
      # A^T is 3x2:
      #   [[0, 3],
      #    [1, 0],
      #    [2, 0]]
      entries = [{0, 1, 1}, {0, 2, 2}, {1, 0, 3}]
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 3, entries, :int64, [])

      assert {:ok, t} = RefBackend.matrix_transpose(a, [])
      assert {:ok, {3, 2}} = Matrix.shape(t)
      assert {:ok, coo} = Matrix.to_coo(t)
      # (0,1) in A -> (1,0) in A^T, value 1
      # (0,2) in A -> (2,0) in A^T, value 2
      # (1,0) in A -> (0,1) in A^T, value 3
      assert Enum.sort(coo) == [{0, 1, 3}, {1, 0, 1}, {2, 0, 2}]
    end

    test "transpose of symmetric matrix equals itself" do
      # Symmetric: (0,1) and (1,0) both present
      entries = [{0, 0, 5}, {0, 1, 3}, {1, 0, 3}, {1, 1, 7}]
      assert {:ok, m} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])

      assert {:ok, t} = RefBackend.matrix_transpose(m, [])
      assert {:ok, coo} = Matrix.to_coo(t)
      assert Enum.sort(coo) == [{0, 0, 5}, {0, 1, 3}, {1, 0, 3}, {1, 1, 7}]
    end
  end

  #############################################################################
  # Dense conversion (to_dense / to_list)
  #############################################################################

  describe "Matrix.to_dense (semantic)" do
    test "converts sparse matrix to dense list-of-lists" do
      # A = [[5, 0],
      #      [0, 7]]
      assert {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 5}, {1, 1, 7}], :int64)
      assert {:ok, dense} = Matrix.to_dense(m)
      assert dense == [[5, 0], [0, 7]]
    end

    test "all-zeros matrix to_dense" do
      assert {:ok, m} = Matrix.new(2, 3, :int64)
      assert {:ok, dense} = Matrix.to_dense(m)
      assert dense == [[0, 0, 0], [0, 0, 0]]
    end

    test "3x3 matrix to_dense" do
      # [[1,0,2],
      #  [0,3,0],
      #  [4,0,5]]
      assert {:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 1}, {0, 2, 2}, {1, 1, 3}, {2, 0, 4}, {2, 2, 5}], :int64)
      assert {:ok, dense} = Matrix.to_dense(m)
      assert dense == [[1, 0, 2], [0, 3, 0], [4, 0, 5]]
    end
  end

  describe "Vector.to_list (semantic)" do
    test "converts sparse vector to dense list" do
      assert {:ok, v} = Vector.from_entries(4, [{0, 5}, {2, 3}], :int64)
      assert {:ok, list} = Vector.to_list(v)
      assert list == [5, 0, 3, 0]
    end

    test "all-zeros vector to_list" do
      assert {:ok, v} = Vector.new(3, :int64)
      assert {:ok, list} = Vector.to_list(v)
      assert list == [0, 0, 0]
    end

    test "full vector to_list" do
      assert {:ok, v} = Vector.from_entries(3, [{0, 10}, {1, 20}, {2, 30}], :int64)
      assert {:ok, list} = Vector.to_list(v)
      assert list == [10, 20, 30]
    end
  end

  #############################################################################
  # Vector ewise operations (semantic)
  #############################################################################

  describe "vector ewise_add (semantic)" do
    test "union with overlapping indices summed" do
      # a = [1, 0, 3] (indices 0 and 2)
      # b = [4, 2, 0] (indices 0 and 1)
      # ewise_add(plus): [5, 2, 3]
      assert {:ok, a} = RefBackend.vector_from_entries(3, [{0, 1}, {2, 3}], :int64, [])
      assert {:ok, b} = RefBackend.vector_from_entries(3, [{0, 4}, {1, 2}], :int64, [])

      assert {:ok, c} = RefBackend.vector_ewise_add(a, b, :plus, [])
      assert {:ok, entries} = Vector.to_entries(c)
      assert {0, 5} in entries
      assert {1, 2} in entries
      assert {2, 3} in entries
    end
  end

  describe "vector ewise_mult (semantic)" do
    test "intersection: only overlapping indices kept" do
      # a = [2, 0, 3] (indices 0 and 2)
      # b = [4, 0, 5] (indices 0 and 2)
      # ewise_mult(times): [8, _, 15]
      assert {:ok, a} = RefBackend.vector_from_entries(3, [{0, 2}, {2, 3}], :int64, [])
      assert {:ok, b} = RefBackend.vector_from_entries(3, [{0, 4}, {2, 5}], :int64, [])

      assert {:ok, c} = RefBackend.vector_ewise_mult(a, b, :times, [])
      assert {:ok, entries} = Vector.to_entries(c)
      assert {0, 8} in entries
      assert {2, 15} in entries
      assert length(entries) == 2
    end
  end
end