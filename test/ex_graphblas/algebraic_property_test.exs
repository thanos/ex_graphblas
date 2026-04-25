defmodule GraphBLAS.AlgebraicPropertyTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.Elixir, as: RefBackend

  defp sort_coo(entries), do: Enum.sort(entries)

  defp sort_vec(entries), do: Enum.sort(entries)

  describe "commutativity of ewise_add" do
    test "matrix: A + B == B + A for :plus monoid" do
      {:ok, a} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 1}, {1, 1, 2}], :int64, [])
      {:ok, b} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 3}, {2, 2, 4}], :int64, [])

      {:ok, ab} = RefBackend.matrix_ewise_add(a, b, :plus, [])
      {:ok, ba} = RefBackend.matrix_ewise_add(b, a, :plus, [])

      {:ok, coo_ab} = RefBackend.matrix_to_coo(ab)
      {:ok, coo_ba} = RefBackend.matrix_to_coo(ba)

      assert sort_coo(coo_ab) == sort_coo(coo_ba)
    end

    test "vector: A + B == B + A for :plus monoid" do
      {:ok, a} = RefBackend.vector_from_entries(4, [{0, 1}, {2, 3}], :int64, [])
      {:ok, b} = RefBackend.vector_from_entries(4, [{0, 5}, {3, 7}], :int64, [])

      {:ok, ab} = RefBackend.vector_ewise_add(a, b, :plus, [])
      {:ok, ba} = RefBackend.vector_ewise_add(b, a, :plus, [])

      {:ok, e_ab} = RefBackend.vector_to_entries(ab)
      {:ok, e_ba} = RefBackend.vector_to_entries(ba)

      assert sort_vec(e_ab) == sort_vec(e_ba)
    end
  end

  describe "associativity of mxm" do
    test "(A*B)*C == A*(B*C) for :plus_times" do
      {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}], :int64, [])
      {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 1}], :int64, [])
      {:ok, c} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 2}, {0, 1, 1}, {1, 0, 3}], :int64, [])

      {:ok, ab} = RefBackend.matrix_mxm(a, b, :plus_times, [])
      {:ok, ab_c} = RefBackend.matrix_mxm(ab, c, :plus_times, [])

      {:ok, bc} = RefBackend.matrix_mxm(b, c, :plus_times, [])
      {:ok, a_bc} = RefBackend.matrix_mxm(a, bc, :plus_times, [])

      {:ok, coo_left} = RefBackend.matrix_to_coo(ab_c)
      {:ok, coo_right} = RefBackend.matrix_to_coo(a_bc)

      assert sort_coo(coo_left) == sort_coo(coo_right)
    end
  end

  describe "transpose properties" do
    test "(A^T)^T == A" do
      entries = [{0, 1, 1}, {1, 0, 2}, {2, 1, 3}]
      {:ok, a} = RefBackend.matrix_from_coo(3, 2, entries, :int64, [])

      {:ok, at} = RefBackend.matrix_transpose(a, [])
      {:ok, att} = RefBackend.matrix_transpose(at, [])

      {:ok, coo_a} = RefBackend.matrix_to_coo(a)
      {:ok, coo_att} = RefBackend.matrix_to_coo(att)

      assert sort_coo(coo_a) == sort_coo(coo_att)
    end

    test "transpose of MxN gives NxM" do
      {:ok, a} = RefBackend.matrix_from_coo(2, 5, [{0, 3, 1}, {1, 4, 2}], :int64, [])
      {:ok, at} = RefBackend.matrix_transpose(a, [])
      assert {:ok, {5, 2}} = RefBackend.matrix_shape(at)
    end

    test "transpose swaps row and column indices" do
      {:ok, a} = RefBackend.matrix_from_coo(3, 3, [{0, 2, 7}, {1, 0, 8}], :int64, [])
      {:ok, at} = RefBackend.matrix_transpose(a, [])
      {:ok, coo} = RefBackend.matrix_to_coo(at)
      assert sort_coo(coo) == [{0, 1, 8}, {2, 0, 7}]
    end
  end

  describe "ewise_add with disjoint entries" do
    test "nvals(A+B) == nvals(A) + nvals(B) when no overlap" do
      {:ok, a} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 1}, {1, 1, 2}], :int64, [])
      {:ok, b} = RefBackend.matrix_from_coo(3, 3, [{2, 2, 3}], :int64, [])

      {:ok, sum} = RefBackend.matrix_ewise_add(a, b, :plus, [])
      {:ok, nvals} = RefBackend.matrix_nvals(sum)

      assert nvals == 3
    end

    test "A + empty == A" do
      entries = [{0, 0, 1}, {1, 1, 2}]
      {:ok, a} = RefBackend.matrix_from_coo(3, 3, entries, :int64, [])
      {:ok, empty} = RefBackend.matrix_new(3, 3, :int64, [])

      {:ok, sum} = RefBackend.matrix_ewise_add(a, empty, :plus, [])
      {:ok, coo_a} = RefBackend.matrix_to_coo(a)
      {:ok, coo_sum} = RefBackend.matrix_to_coo(sum)

      assert sort_coo(coo_a) == sort_coo(coo_sum)
    end
  end

  describe "reduce properties" do
    test "vector_reduce of single entry returns that value" do
      {:ok, v} = RefBackend.vector_from_entries(5, [{2, 42}], :int64, [])
      {:ok, %GraphBLAS.Scalar{value: val}} = RefBackend.vector_reduce(v, :plus, [])
      assert val == 42
    end

    test "matrix_reduce sums each row" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 3, [{0, 0, 1}, {0, 2, 3}, {1, 1, 5}], :int64, [])
      {:ok, v} = RefBackend.matrix_reduce(m, :plus, [])
      {:ok, entries} = RefBackend.vector_to_entries(v)
      assert sort_vec(entries) == [{0, 4}, {1, 5}]
    end
  end

  describe "dup independence" do
    test "matrix_dup produces independent copy" do
      {:ok, m} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 1}], :int64, [])
      {:ok, dup} = RefBackend.matrix_dup(m)
      {:ok, modified} = RefBackend.matrix_set(dup, 1, 1, 99)

      {:ok, orig_coo} = RefBackend.matrix_to_coo(m)
      {:ok, mod_coo} = RefBackend.matrix_to_coo(modified)

      assert sort_coo(orig_coo) == [{0, 0, 1}]
      assert sort_coo(mod_coo) == [{0, 0, 1}, {1, 1, 99}]
    end

    test "vector_dup produces independent copy" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 10}], :int64, [])
      {:ok, dup} = RefBackend.vector_dup(v)
      {:ok, modified} = RefBackend.vector_set(dup, 2, 77)

      {:ok, orig_entries} = RefBackend.vector_to_entries(v)
      {:ok, mod_entries} = RefBackend.vector_to_entries(modified)

      assert sort_vec(orig_entries) == [{0, 10}]
      assert sort_vec(mod_entries) == [{0, 10}, {2, 77}]
    end
  end
end
