defmodule GraphBLAS.MatrixAPITest do
  use ExUnit.Case, async: true

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

  describe "Matrix.transpose/2" do
    test "transposes a non-square matrix" do
      entries = [{0, 1, 5}, {2, 0, 7}]
      assert {:ok, m} = Matrix.from_coo(3, 2, entries, :int64)
      assert {:ok, t} = Matrix.transpose(m)
      assert {:ok, {2, 3}} = Matrix.shape(t)
    end
  end
end
