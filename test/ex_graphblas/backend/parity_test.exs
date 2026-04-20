defmodule GraphBLAS.Backend.ParityTest do
  use ExUnit.Case, async: false

  alias GraphBLAS.Backend.Elixir, as: RefBackend
  alias GraphBLAS.Backend.SuiteSparse

  describe "matrix_from_coo parity" do
    test "int64: both backends produce same COO output" do
      entries = [{0, 1, 5}, {1, 0, 3}, {2, 2, 7}]

      {:ok, ref} = RefBackend.matrix_from_coo(3, 3, entries, :int64, [])
      {:ok, ss} = SuiteSparse.matrix_from_coo(3, 3, entries, :int64, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)
      SuiteSparse.matrix_free(ss)
    end

    test "fp64: both backends produce same COO output" do
      entries = [{0, 0, 1.5}, {1, 1, 2.5}, {0, 2, 3.0}]

      {:ok, ref} = RefBackend.matrix_from_coo(2, 3, entries, :fp64, [])
      {:ok, ss} = SuiteSparse.matrix_from_coo(2, 3, entries, :fp64, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss)

      assert_coo_approx_equal(ref_coo, ss_coo)
      SuiteSparse.matrix_free(ss)
    end

    test "bool: both backends produce same COO output" do
      entries = [{0, 0, true}, {1, 1, true}, {0, 2, true}]

      {:ok, ref} = RefBackend.matrix_from_coo(2, 3, entries, :bool, [])
      {:ok, ss} = SuiteSparse.matrix_from_coo(2, 3, entries, :bool, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)
      SuiteSparse.matrix_free(ss)
    end

    test "duplicate entries are combined with plus monoid" do
      entries = [{0, 0, 1}, {0, 0, 2}]

      {:ok, ref} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
      {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss)

      assert length(ref_coo) == 1
      assert length(ss_coo) == 1
      assert {0, 0, 3} in sort_coo(ss_coo)
      SuiteSparse.matrix_free(ss)
    end
  end

  describe "matrix_mxm parity" do
    test "int64: both backends produce same multiplication result" do
      entries_a = [{0, 1, 1}, {1, 2, 1}]
      entries_b = [{1, 0, 2}, {2, 1, 3}]

      {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, entries_a, :int64, [])
      {:ok, ref_b} = RefBackend.matrix_from_coo(3, 2, entries_b, :int64, [])
      {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, entries_a, :int64, [])
      {:ok, ss_b} = SuiteSparse.matrix_from_coo(3, 2, entries_b, :int64, [])

      {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times, [])
      {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :plus_times, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)
      SuiteSparse.matrix_free(ss_a)
      SuiteSparse.matrix_free(ss_b)
      SuiteSparse.matrix_free(ss_c)
    end

    test "bool: lor_land semiring parity" do
      entries_a = [{0, 1, true}, {1, 2, true}]
      entries_b = [{1, 0, true}, {2, 1, true}]

      {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, entries_a, :bool, [])
      {:ok, ref_b} = RefBackend.matrix_from_coo(3, 2, entries_b, :bool, [])
      {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, entries_a, :bool, [])
      {:ok, ss_b} = SuiteSparse.matrix_from_coo(3, 2, entries_b, :bool, [])

      {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, :lor_land, [])
      {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :lor_land, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)
      SuiteSparse.matrix_free(ss_a)
      SuiteSparse.matrix_free(ss_b)
      SuiteSparse.matrix_free(ss_c)
    end
  end

  describe "matrix_transpose parity" do
    test "int64: both backends produce same transpose" do
      entries = [{0, 1, 5}, {1, 0, 3}]

      {:ok, ref} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
      {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])

      {:ok, ref_t} = RefBackend.matrix_transpose(ref, [])
      {:ok, ss_t} = SuiteSparse.matrix_transpose(ss, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_t)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_t)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)
      SuiteSparse.matrix_free(ss)
      SuiteSparse.matrix_free(ss_t)
    end
  end

  describe "matrix_ewise_add parity" do
    test "int64: both backends produce same element-wise addition" do
      {:ok, ref_a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64, [])
      {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 3}, {1, 1, 4}], :int64, [])
      {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64, [])
      {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 3}, {1, 1, 4}], :int64, [])

      {:ok, ref_c} = RefBackend.matrix_ewise_add(ref_a, ref_b, :plus, [])
      {:ok, ss_c} = SuiteSparse.matrix_ewise_add(ss_a, ss_b, :plus, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)
      SuiteSparse.matrix_free(ss_a)
      SuiteSparse.matrix_free(ss_b)
      SuiteSparse.matrix_free(ss_c)
    end
  end

  describe "matrix_reduce parity" do
    test "int64: both backends reduce rows to vector" do
      entries = [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}]
      {:ok, ref} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
      {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])

      {:ok, ref_v} = RefBackend.matrix_reduce(ref, :plus, [])
      {:ok, ss_v} = SuiteSparse.matrix_reduce(ss, :plus, [])

      {:ok, ref_entries} = RefBackend.vector_to_entries(ref_v)
      {:ok, ss_entries} = SuiteSparse.vector_to_entries(ss_v)

      assert sort_entries(ref_entries) == sort_entries(ss_entries)
      SuiteSparse.matrix_free(ss)
      SuiteSparse.vector_free(ss_v)
    end
  end

  describe "vector operations parity" do
    test "int64: vector creation and extraction" do
      entries = [{0, 10}, {1, 20}, {2, 30}]

      {:ok, ref} = RefBackend.vector_from_entries(4, entries, :int64, [])
      {:ok, ss} = SuiteSparse.vector_from_entries(4, entries, :int64, [])

      {:ok, ref_e} = RefBackend.vector_to_entries(ref)
      {:ok, ss_e} = SuiteSparse.vector_to_entries(ss)

      assert sort_entries(ref_e) == sort_entries(ss_e)
      SuiteSparse.vector_free(ss)
    end

    test "int64: vector ewise_add" do
      {:ok, ref_a} = RefBackend.vector_from_entries(3, [{0, 1}, {1, 2}], :int64, [])
      {:ok, ref_b} = RefBackend.vector_from_entries(3, [{0, 3}, {1, 4}], :int64, [])
      {:ok, ss_a} = SuiteSparse.vector_from_entries(3, [{0, 1}, {1, 2}], :int64, [])
      {:ok, ss_b} = SuiteSparse.vector_from_entries(3, [{0, 3}, {1, 4}], :int64, [])

      {:ok, ref_c} = RefBackend.vector_ewise_add(ref_a, ref_b, :plus, [])
      {:ok, ss_c} = SuiteSparse.vector_ewise_add(ss_a, ss_b, :plus, [])

      {:ok, ref_e} = RefBackend.vector_to_entries(ref_c)
      {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_c)

      assert sort_entries(ref_e) == sort_entries(ss_e)
      SuiteSparse.vector_free(ss_a)
      SuiteSparse.vector_free(ss_b)
      SuiteSparse.vector_free(ss_c)
    end

    test "int64: vector reduce" do
      {:ok, ref} = RefBackend.vector_from_entries(3, [{0, 10}, {1, 20}, {2, 30}], :int64, [])
      {:ok, ss} = SuiteSparse.vector_from_entries(3, [{0, 10}, {1, 20}, {2, 30}], :int64, [])

      {:ok, ref_s} = RefBackend.vector_reduce(ref, :plus, [])
      {:ok, ss_s} = SuiteSparse.vector_reduce(ss, :plus, [])

      assert ref_s.value == ss_s.value
      SuiteSparse.vector_free(ss)
    end

    test "fp64: vector reduce" do
      {:ok, ref} = RefBackend.vector_from_entries(3, [{0, 1.5}, {1, 2.5}], :fp64, [])
      {:ok, ss} = SuiteSparse.vector_from_entries(3, [{0, 1.5}, {1, 2.5}], :fp64, [])

      {:ok, ref_s} = RefBackend.vector_reduce(ref, :plus_fp64, [])
      {:ok, ss_s} = SuiteSparse.vector_reduce(ss, :plus_fp64, [])

      assert_in_delta ref_s.value, ss_s.value, 0.001
      SuiteSparse.vector_free(ss)
    end

    test "bool: vector reduce lor" do
      {:ok, ref} = RefBackend.vector_from_entries(3, [{0, true}, {1, true}], :bool, [])
      {:ok, ss} = SuiteSparse.vector_from_entries(3, [{0, true}, {1, true}], :bool, [])

      {:ok, ref_s} = RefBackend.vector_reduce(ref, :lor, [])
      {:ok, ss_s} = SuiteSparse.vector_reduce(ss, :lor, [])

      assert ref_s.value == ss_s.value
      SuiteSparse.vector_free(ss)
    end
  end

  describe "matrix_mxv parity" do
    test "int64: matrix-vector multiplication" do
      {:ok, ref_m} = RefBackend.matrix_from_coo(2, 3, [{0, 1, 2}, {1, 2, 3}], :int64, [])
      {:ok, ref_v} = RefBackend.vector_from_entries(3, [{1, 10}, {2, 5}], :int64, [])
      {:ok, ss_m} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 2}, {1, 2, 3}], :int64, [])
      {:ok, ss_v} = SuiteSparse.vector_from_entries(3, [{1, 10}, {2, 5}], :int64, [])

      {:ok, ref_r} = RefBackend.matrix_mxv(ref_m, ref_v, :plus_times, [])
      {:ok, ss_r} = SuiteSparse.matrix_mxv(ss_m, ss_v, :plus_times, [])

      {:ok, ref_e} = RefBackend.vector_to_entries(ref_r)
      {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_r)

      assert sort_entries(ref_e) == sort_entries(ss_e)
      SuiteSparse.matrix_free(ss_m)
      SuiteSparse.vector_free(ss_v)
      SuiteSparse.vector_free(ss_r)
    end
  end

  describe "matrix_ewise_mult parity" do
    test "int64: element-wise multiplication" do
      {:ok, ref_a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 2}, {1, 1, 3}], :int64, [])
      {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 4}, {1, 1, 5}], :int64, [])
      {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 2}, {1, 1, 3}], :int64, [])
      {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 4}, {1, 1, 5}], :int64, [])

      {:ok, ref_c} = RefBackend.matrix_ewise_mult(ref_a, ref_b, :times, [])
      {:ok, ss_c} = SuiteSparse.matrix_ewise_mult(ss_a, ss_b, :times, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)
      SuiteSparse.matrix_free(ss_a)
      SuiteSparse.matrix_free(ss_b)
      SuiteSparse.matrix_free(ss_c)
    end
  end

  describe "vector_vxm parity" do
    test "int64: vector-matrix multiplication" do
      {:ok, ref_v} = RefBackend.vector_from_entries(3, [{0, 1}, {2, 2}], :int64, [])
      {:ok, ref_m} = RefBackend.matrix_from_coo(3, 2, [{0, 0, 3}, {2, 1, 4}], :int64, [])
      {:ok, ss_v} = SuiteSparse.vector_from_entries(3, [{0, 1}, {2, 2}], :int64, [])
      {:ok, ss_m} = SuiteSparse.matrix_from_coo(3, 2, [{0, 0, 3}, {2, 1, 4}], :int64, [])

      {:ok, ref_r} = RefBackend.vector_vxm(ref_v, ref_m, :plus_times, [])
      {:ok, ss_r} = SuiteSparse.vector_vxm(ss_v, ss_m, :plus_times, [])

      {:ok, ref_e} = RefBackend.vector_to_entries(ref_r)
      {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_r)

      assert sort_entries(ref_e) == sort_entries(ss_e)
      SuiteSparse.vector_free(ss_v)
      SuiteSparse.matrix_free(ss_m)
      SuiteSparse.vector_free(ss_r)
    end
  end

  describe "vector_ewise_mult parity" do
    test "int64: element-wise multiplication" do
      {:ok, ref_a} = RefBackend.vector_from_entries(3, [{0, 2}, {1, 3}], :int64, [])
      {:ok, ref_b} = RefBackend.vector_from_entries(3, [{0, 4}, {1, 5}], :int64, [])
      {:ok, ss_a} = SuiteSparse.vector_from_entries(3, [{0, 2}, {1, 3}], :int64, [])
      {:ok, ss_b} = SuiteSparse.vector_from_entries(3, [{0, 4}, {1, 5}], :int64, [])

      {:ok, ref_c} = RefBackend.vector_ewise_mult(ref_a, ref_b, :times, [])
      {:ok, ss_c} = SuiteSparse.vector_ewise_mult(ss_a, ss_b, :times, [])

      {:ok, ref_e} = RefBackend.vector_to_entries(ref_c)
      {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_c)

      assert sort_entries(ref_e) == sort_entries(ss_e)
      SuiteSparse.vector_free(ss_a)
      SuiteSparse.vector_free(ss_b)
      SuiteSparse.vector_free(ss_c)
    end
  end

  describe "matrix_to_dense parity" do
    test "int64: both backends produce same dense representation" do
      entries = [{0, 1, 5}, {1, 0, 3}]

      {:ok, ref} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
      {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])

      {:ok, ref_dense} = RefBackend.matrix_to_dense(ref)
      {:ok, ss_dense} = SuiteSparse.matrix_to_dense(ss)

      assert ref_dense == ss_dense
      SuiteSparse.matrix_free(ss)
    end
  end

  describe "vector_to_list parity" do
    test "int64: both backends produce same dense list" do
      entries = [{0, 5}, {2, 3}]

      {:ok, ref} = RefBackend.vector_from_entries(4, entries, :int64, [])
      {:ok, ss} = SuiteSparse.vector_from_entries(4, entries, :int64, [])

      {:ok, ref_list} = RefBackend.vector_to_list(ref)
      {:ok, ss_list} = SuiteSparse.vector_to_list(ss)

      assert ref_list == ss_list
      SuiteSparse.vector_free(ss)
    end
  end

  defp sort_coo(entries) do
    Enum.sort_by(entries, fn {r, c, _v} -> {r, c} end)
  end

  defp sort_entries(entries) do
    Enum.sort_by(entries, fn {i, _v} -> i end)
  end

  defp assert_coo_approx_equal(ref, ss) do
    ref_sorted = sort_coo(ref)
    ss_sorted = sort_coo(ss)

    assert length(ref_sorted) == length(ss_sorted)

    Enum.zip_with(ref_sorted, ss_sorted, fn {r1, c1, v1}, {r2, c2, v2} ->
      assert r1 == r2
      assert c1 == c2
      assert_in_delta v1, v2, 0.001
    end)
  end
end
