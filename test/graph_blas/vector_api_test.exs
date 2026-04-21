defmodule GraphBLAS.VectorAPITest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Vector

  describe "Vector.from_entries/4" do
    test "creates a vector via public API" do
      assert {:ok, v} = Vector.from_entries(4, [{0, 1.0}, {2, 3.0}], :fp64)
      assert {:ok, 4} = Vector.size(v)
      assert {:ok, :fp64} = Vector.type(v)
      assert {:ok, 2} = Vector.nvals(v)
    end
  end

  describe "Vector.new/3" do
    test "creates an empty vector" do
      assert {:ok, v} = Vector.new(10, :int64)
      assert {:ok, 0} = Vector.nvals(v)
    end
  end

  describe "Vector.ewise_add/4" do
    test "adds two vectors" do
      assert {:ok, a} = Vector.from_entries(3, [{0, 1}, {1, 2}], :int64)
      assert {:ok, b} = Vector.from_entries(3, [{0, 3}, {2, 4}], :int64)
      assert {:ok, c} = Vector.ewise_add(a, b)
      assert {:ok, entries} = Vector.to_entries(c)
      assert {0, 4} in entries
    end
  end

  describe "Vector.reduce/3" do
    test "reduces a vector to a scalar" do
      assert {:ok, v} = Vector.from_entries(3, [{0, 10}, {1, 20}, {2, 30}], :int64)
      assert {:ok, scalar} = Vector.reduce(v, :plus)
      assert GraphBLAS.Scalar.value(scalar) == 60
    end
  end
end
