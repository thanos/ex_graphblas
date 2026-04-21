defmodule GraphBLAS.VectorAPITest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.Elixir, as: RefBackend
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

  describe "Vector.ewise_mult/4" do
    test "multiplies two vectors" do
      assert {:ok, a} = Vector.from_entries(3, [{0, 2}, {1, 3}], :int64)
      assert {:ok, b} = Vector.from_entries(3, [{0, 4}, {1, 5}], :int64)
      assert {:ok, c} = Vector.ewise_mult(a, b, :times)
      assert {:ok, entries} = Vector.to_entries(c)
      assert {0, 8} in entries
      assert {1, 15} in entries
    end
  end

  describe "Vector.reduce/3" do
    test "reduces a vector to a scalar" do
      assert {:ok, v} = Vector.from_entries(3, [{0, 10}, {1, 20}, {2, 30}], :int64)
      assert {:ok, scalar} = Vector.reduce(v, :plus)
      assert GraphBLAS.Scalar.value(scalar) == 60
    end
  end

  describe "Vector.vxm/4" do
    test "multiplies vector by matrix" do
      assert {:ok, v} = Vector.from_entries(3, [{0, 1}, {2, 2}], :int64)
      assert {:ok, m} = GraphBLAS.Matrix.from_coo(3, 2, [{0, 0, 3}, {2, 1, 4}], :int64)
      assert {:ok, r} = Vector.vxm(v, m, :plus_times)
      assert {:ok, 2} = Vector.size(r)
    end
  end

  describe "Vector.to_list/1" do
    test "converts sparse vector to dense list" do
      assert {:ok, v} = Vector.from_entries(4, [{0, 5}, {2, 3}], :int64)
      assert {:ok, list} = Vector.to_list(v)
      assert list == [5, 0, 3, 0]
    end

    test "converts fp64 vector to dense list" do
      assert {:ok, v} = Vector.from_entries(3, [{0, 1.5}, {1, 2.5}], :fp64)
      assert {:ok, list} = Vector.to_list(v)
      assert list == [1.5, 2.5, 0.0]
    end

    test "converts bool vector to dense list" do
      assert {:ok, v} = Vector.from_entries(3, [{0, true}, {2, true}], :bool)
      assert {:ok, list} = Vector.to_list(v)
      assert list == [true, false, true]
    end
  end

  describe "Vector.set/4" do
    test "sets a value at index" do
      {:ok, v} = Vector.from_entries(3, [{0, 1}], :int64)
      {:ok, updated} = Vector.set(v, 1, 5)
      {:ok, 5} = Vector.extract(updated, 1)
    end

    test "overwrites existing value" do
      {:ok, v} = Vector.from_entries(3, [{0, 1}], :int64)
      {:ok, updated} = Vector.set(v, 0, 42)
      {:ok, 42} = Vector.extract(updated, 0)
    end
  end

  describe "Vector.extract/3" do
    test "returns default for structural zero" do
      {:ok, v} = Vector.from_entries(3, [{0, 42}], :int64)
      {:ok, 0} = Vector.extract(v, 1)
    end

    test "returns stored value" do
      {:ok, v} = Vector.from_entries(3, [{0, 42}], :int64)
      {:ok, 42} = Vector.extract(v, 0)
    end
  end

  describe "Vector.dup/3" do
    test "creates an independent copy" do
      {:ok, v} = Vector.from_entries(3, [{0, 1}, {1, 2}], :int64)
      {:ok, copy} = Vector.dup(v)
      {:ok, entries_orig} = Vector.to_entries(v)
      {:ok, entries_copy} = Vector.to_entries(copy)
      assert Enum.sort(entries_orig) == Enum.sort(entries_copy)
    end
  end

  describe "Vector with explicit backend option" do
    test "delegates to specified backend" do
      assert {:ok, v} = Vector.from_entries(3, [{0, 1}], :int64, backend: RefBackend)
      assert {:ok, 3} = Vector.size(v)
    end
  end
end
