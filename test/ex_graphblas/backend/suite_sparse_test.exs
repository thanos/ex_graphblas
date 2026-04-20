defmodule GraphBLAS.SuiteSparseBackendTest do
  use ExUnit.Case, async: false

  alias GraphBLAS.Backend.SuiteSparse

  describe "matrix_new" do
    test "creates an empty matrix with correct shape" do
      {:ok, m} = SuiteSparse.matrix_new(3, 4, :int64, [])
      assert {:ok, {3, 4}} = SuiteSparse.matrix_shape(m)
      assert {:ok, :int64} = SuiteSparse.matrix_type(m)
      assert {:ok, 0} = SuiteSparse.matrix_nvals(m)
      SuiteSparse.matrix_free(m)
    end

    test "rejects unsupported types" do
      assert {:error, %GraphBLAS.Error{reason: {:unsupported_type, :int32}}} =
               SuiteSparse.matrix_new(3, 3, :int32, [])
    end
  end

  describe "matrix_from_coo" do
    test "creates matrix from COO entries" do
      entries = [{0, 1, 5}, {1, 0, 3}, {2, 2, 7}]
      {:ok, m} = SuiteSparse.matrix_from_coo(3, 3, entries, :int64, [])
      assert {:ok, 3} = SuiteSparse.matrix_nvals(m)
      SuiteSparse.matrix_free(m)
    end

    test "creates bool matrix from COO entries" do
      entries = [{0, 0, true}, {1, 1, true}]
      {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, entries, :bool, [])
      assert {:ok, 2} = SuiteSparse.matrix_nvals(m)
      SuiteSparse.matrix_free(m)
    end

    test "creates fp64 matrix from COO entries" do
      entries = [{0, 0, 1.5}, {1, 1, 2.5}]
      {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, entries, :fp64, [])
      assert {:ok, 2} = SuiteSparse.matrix_nvals(m)
      SuiteSparse.matrix_free(m)
    end
  end

  describe "matrix_to_coo" do
    test "extracts COO entries matching input" do
      entries = [{0, 1, 5}, {1, 0, 3}]
      {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])
      {:ok, result} = SuiteSparse.matrix_to_coo(m)

      sorted = Enum.sort_by(result, fn {r, c, _v} -> {r, c} end)
      assert sorted == [{0, 1, 5}, {1, 0, 3}]
      SuiteSparse.matrix_free(m)
    end
  end

  describe "matrix_mxm" do
    test "multiplies two matrices" do
      {:ok, a} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 1}, {1, 2, 2}], :int64, [])
      {:ok, b} = SuiteSparse.matrix_from_coo(3, 2, [{1, 0, 3}, {2, 1, 4}], :int64, [])
      {:ok, c} = SuiteSparse.matrix_mxm(a, b, :plus_times, [])
      assert {:ok, {2, 2}} = SuiteSparse.matrix_shape(c)
      {:ok, nvals} = SuiteSparse.matrix_nvals(c)
      assert nvals > 0
      SuiteSparse.matrix_free(a)
      SuiteSparse.matrix_free(b)
      SuiteSparse.matrix_free(c)
    end
  end

  describe "matrix_transpose" do
    test "transposes a matrix" do
      entries = [{0, 1, 5}, {1, 0, 3}]
      {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])
      {:ok, t} = SuiteSparse.matrix_transpose(m, [])
      {:ok, result} = SuiteSparse.matrix_to_coo(t)

      sorted = Enum.sort_by(result, fn {r, c, _v} -> {r, c} end)
      assert sorted == [{0, 1, 3}, {1, 0, 5}]
      SuiteSparse.matrix_free(m)
      SuiteSparse.matrix_free(t)
    end
  end

  describe "matrix_ewise_add" do
    test "element-wise addition of two matrices" do
      {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64, [])
      {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 3}, {1, 1, 4}], :int64, [])
      {:ok, c} = SuiteSparse.matrix_ewise_add(a, b, :plus, [])
      {:ok, result} = SuiteSparse.matrix_to_coo(c)

      sorted = Enum.sort_by(result, fn {r, c, _v} -> {r, c} end)
      assert {0, 0, 4} in sorted
      assert {1, 1, 6} in sorted
      SuiteSparse.matrix_free(a)
      SuiteSparse.matrix_free(b)
      SuiteSparse.matrix_free(c)
    end
  end

  describe "vector operations" do
    test "creates vector and extracts entries" do
      {:ok, v} = SuiteSparse.vector_from_entries(4, [{0, 10}, {2, 30}], :int64, [])
      assert {:ok, 2} = SuiteSparse.vector_nvals(v)
      assert {:ok, 4} = SuiteSparse.vector_size(v)
      {:ok, entries} = SuiteSparse.vector_to_entries(v)
      assert {0, 10} in entries
      assert {2, 30} in entries
      SuiteSparse.vector_free(v)
    end

    test "element-wise addition of two vectors" do
      {:ok, a} = SuiteSparse.vector_from_entries(3, [{0, 1}, {1, 2}], :int64, [])
      {:ok, b} = SuiteSparse.vector_from_entries(3, [{0, 3}, {1, 4}], :int64, [])
      {:ok, c} = SuiteSparse.vector_ewise_add(a, b, :plus, [])
      {:ok, entries} = SuiteSparse.vector_to_entries(c)
      assert {0, 4} in entries
      assert {1, 6} in entries
      SuiteSparse.vector_free(a)
      SuiteSparse.vector_free(b)
      SuiteSparse.vector_free(c)
    end

    test "reduces a vector to a scalar" do
      {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 10}, {1, 20}, {2, 30}], :int64, [])
      {:ok, scalar} = SuiteSparse.vector_reduce(v, :plus, [])
      assert scalar.value == 60
      SuiteSparse.vector_free(v)
    end
  end
end
