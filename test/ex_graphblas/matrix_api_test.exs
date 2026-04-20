defmodule GraphBLAS.MatrixAPITest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.Elixir, as: RefBackend
  alias GraphBLAS.Matrix

  describe "Matrix.from_coo/5" do
    test "creates a matrix via public API" do
      assert {:ok, m} = Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 2}], :int64)
      assert {:ok, {3, 3}} = Matrix.shape(m)
      assert {:ok, :int64} = Matrix.type(m)
      assert {:ok, 2} = Matrix.nvals(m)
    end
  end

  describe "Matrix.new/4" do
    test "creates an empty matrix" do
      assert {:ok, m} = Matrix.new(4, 4, :fp64)
      assert {:ok, {4, 4}} = Matrix.shape(m)
      assert {:ok, 0} = Matrix.nvals(m)
    end
  end

  describe "Matrix.mxm/4" do
    test "multiplies two matrices via public API" do
      assert {:ok, a} = Matrix.from_coo(2, 2, [{0, 1, 1}, {1, 0, 1}], :int64)
      assert {:ok, b} = Matrix.from_coo(2, 2, [{0, 0, 2}, {1, 1, 3}], :int64)
      assert {:ok, c} = Matrix.mxm(a, b, :plus_times)
      assert {:ok, {2, 2}} = Matrix.shape(c)
    end
  end

  describe "Matrix.mxv/4" do
    test "multiplies matrix by vector via public API" do
      assert {:ok, m} = Matrix.from_coo(2, 3, [{0, 1, 2}, {1, 2, 3}], :int64)
      assert {:ok, v} = GraphBLAS.Vector.from_entries(3, [{1, 5}, {2, 7}], :int64)
      assert {:ok, r} = Matrix.mxv(m, v, :plus_times)
      assert {:ok, 2} = GraphBLAS.Vector.size(r)
    end
  end

  describe "Matrix.ewise_add/4" do
    test "element-wise addition via public API" do
      assert {:ok, a} = Matrix.from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64)
      assert {:ok, b} = Matrix.from_coo(2, 2, [{0, 0, 3}, {1, 1, 4}], :int64)
      assert {:ok, c} = Matrix.ewise_add(a, b, :plus)
      assert {:ok, coo} = Matrix.to_coo(c)
      assert {0, 0, 4} in coo
      assert {1, 1, 6} in coo
    end
  end

  describe "Matrix.ewise_mult/4" do
    test "element-wise multiplication via public API" do
      assert {:ok, a} = Matrix.from_coo(2, 2, [{0, 0, 2}, {1, 1, 3}], :int64)
      assert {:ok, b} = Matrix.from_coo(2, 2, [{0, 0, 4}, {1, 1, 5}], :int64)
      assert {:ok, c} = Matrix.ewise_mult(a, b, :times)
      assert {:ok, coo} = Matrix.to_coo(c)
      assert {0, 0, 8} in coo
      assert {1, 1, 15} in coo
    end
  end

  describe "Matrix.reduce/3" do
    test "reduces matrix to vector via public API" do
      assert {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}], :int64)
      assert {:ok, v} = Matrix.reduce(m, :plus)
      assert {:ok, entries} = GraphBLAS.Vector.to_entries(v)
      assert {0, 3} in entries
      assert {1, 3} in entries
    end
  end

  describe "Matrix.transpose/2" do
    test "transposes a non-square matrix" do
      entries = [{0, 1, 5}, {2, 0, 7}]
      assert {:ok, m} = Matrix.from_coo(3, 2, entries, :int64)
      assert {:ok, t} = Matrix.transpose(m)
      assert {:ok, {2, 3}} = Matrix.shape(t)
    end
  end

  describe "Matrix.to_dense/1" do
    test "converts sparse matrix to dense list-of-lists" do
      assert {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 5}, {1, 1, 7}], :int64)
      assert {:ok, dense} = Matrix.to_dense(m)
      assert dense == [[5, 0], [0, 7]]
    end

    test "to_dense with fp64 matrix" do
      assert {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1.5}, {1, 1, 2.5}], :fp64)
      assert {:ok, dense} = Matrix.to_dense(m)
      assert dense == [[1.5, 0.0], [0.0, 2.5]]
    end
  end

  describe "Matrix with explicit backend option" do
    test "delegates to specified backend" do
      assert {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64, backend: RefBackend)
      assert {:ok, {2, 2}} = Matrix.shape(m)
    end
  end
end
