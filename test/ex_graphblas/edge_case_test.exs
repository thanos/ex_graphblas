defmodule GraphBLAS.EdgeCaseTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.Elixir, as: RefBackend
  alias GraphBLAS.{Error, Matrix, Vector}

  describe "zero-dimension matrices" do
    test "matrix_new(0, 0) succeeds" do
      assert {:ok, %Matrix{shape: {0, 0}}} = RefBackend.matrix_new(0, 0, :int64, [])
    end

    test "matrix_from_coo(0, 0, []) succeeds" do
      assert {:ok, %Matrix{shape: {0, 0}}} = RefBackend.matrix_from_coo(0, 0, [], :int64, [])
    end

    test "nvals of empty 0x0 matrix is 0" do
      {:ok, m} = RefBackend.matrix_new(0, 0, :int64, [])
      assert {:ok, 0} = RefBackend.matrix_nvals(m)
    end

    test "to_coo of empty 0x0 matrix is []" do
      {:ok, m} = RefBackend.matrix_new(0, 0, :int64, [])
      assert {:ok, []} = RefBackend.matrix_to_coo(m)
    end

    test "matrix_new(0, 5) succeeds" do
      assert {:ok, %Matrix{shape: {0, 5}}} = RefBackend.matrix_new(0, 5, :int64, [])
    end

    test "matrix_new(5, 0) succeeds" do
      assert {:ok, %Matrix{shape: {5, 0}}} = RefBackend.matrix_new(5, 0, :int64, [])
    end
  end

  describe "zero-size vectors" do
    test "vector_new(0) succeeds" do
      assert {:ok, %Vector{size: 0}} = RefBackend.vector_new(0, :int64, [])
    end

    test "vector_from_entries(0, []) succeeds" do
      assert {:ok, %Vector{size: 0}} = RefBackend.vector_from_entries(0, [], :int64, [])
    end

    test "nvals of empty vector is 0" do
      {:ok, v} = RefBackend.vector_new(0, :int64, [])
      assert {:ok, 0} = RefBackend.vector_nvals(v)
    end

    test "to_entries of empty vector is []" do
      {:ok, v} = RefBackend.vector_new(0, :int64, [])
      assert {:ok, []} = RefBackend.vector_to_entries(v)
    end
  end

  describe "negative dimensions" do
    test "matrix_new rejects negative nrows" do
      assert {:error, %Error{reason: {:invalid_argument, _}}} =
               RefBackend.matrix_new(-1, 3, :int64, [])
    end

    test "matrix_new rejects negative ncols" do
      assert {:error, %Error{reason: {:invalid_argument, _}}} =
               RefBackend.matrix_new(3, -1, :int64, [])
    end

    test "vector_new rejects negative size" do
      assert {:error, %Error{reason: {:invalid_argument, _}}} =
               RefBackend.vector_new(-1, :int64, [])
    end
  end

  describe "out-of-bounds column indices" do
    test "matrix_from_coo rejects out-of-bounds column" do
      assert {:error, %Error{reason: {:index_out_of_bounds, 5, :col, 2}}} =
               RefBackend.matrix_from_coo(2, 2, [{0, 5, 1}], :int64, [])
    end

    test "vector_from_entries rejects out-of-bounds index" do
      assert {:error, %Error{reason: {:index_out_of_bounds, 5, :index, 2}}} =
               RefBackend.vector_from_entries(2, [{5, 1}], :int64, [])
    end
  end

  describe "dup of empty containers" do
    test "matrix_dup of empty matrix" do
      {:ok, m} = RefBackend.matrix_new(3, 3, :int64, [])
      {:ok, dup} = RefBackend.matrix_dup(m)
      assert {:ok, 0} = RefBackend.matrix_nvals(dup)
      assert {:ok, {3, 3}} = RefBackend.matrix_shape(dup)
    end

    test "vector_dup of empty vector" do
      {:ok, v} = RefBackend.vector_new(5, :int64, [])
      {:ok, dup} = RefBackend.vector_dup(v)
      assert {:ok, 0} = RefBackend.vector_nvals(dup)
      assert {:ok, 5} = RefBackend.vector_size(dup)
    end
  end

  describe "all type variants" do
    test "matrix_new :int64" do
      assert {:ok, %Matrix{type: :int64}} = RefBackend.matrix_new(2, 2, :int64, [])
    end

    test "matrix_new :fp64" do
      assert {:ok, %Matrix{type: :fp64}} = RefBackend.matrix_new(2, 2, :fp64, [])
    end

    test "matrix_new :bool" do
      assert {:ok, %Matrix{type: :bool}} = RefBackend.matrix_new(2, 2, :bool, [])
    end

    test "vector_new :int64" do
      assert {:ok, %Vector{type: :int64}} = RefBackend.vector_new(3, :int64, [])
    end

    test "vector_new :fp64" do
      assert {:ok, %Vector{type: :fp64}} = RefBackend.vector_new(3, :fp64, [])
    end

    test "vector_new :bool" do
      assert {:ok, %Vector{type: :bool}} = RefBackend.vector_new(3, :bool, [])
    end
  end

  describe "set on empty containers" do
    test "matrix_set adds entry to empty matrix" do
      {:ok, m} = RefBackend.matrix_new(3, 3, :int64, [])
      {:ok, m2} = RefBackend.matrix_set(m, 1, 2, 42)
      assert {:ok, 1} = RefBackend.matrix_nvals(m2)
      {:ok, coo} = RefBackend.matrix_to_coo(m2)
      assert [{1, 2, 42}] = coo
    end

    test "vector_set adds entry to empty vector" do
      {:ok, v} = RefBackend.vector_new(5, :int64, [])
      {:ok, v2} = RefBackend.vector_set(v, 3, 99)
      assert {:ok, 1} = RefBackend.vector_nvals(v2)
      {:ok, entries} = RefBackend.vector_to_entries(v2)
      assert [{3, 99}] = entries
    end
  end

  describe "to_dense of empty matrix" do
    test "returns grid of default values" do
      {:ok, m} = RefBackend.matrix_new(2, 3, :int64, [])
      {:ok, dense} = RefBackend.matrix_to_dense(m)
      assert dense == [[0, 0, 0], [0, 0, 0]]
    end
  end

  describe "to_list of empty vector" do
    test "returns list of default values" do
      {:ok, v} = RefBackend.vector_new(3, :fp64, [])
      {:ok, list} = RefBackend.vector_to_list(v)
      assert list == [0.0, 0.0, 0.0]
    end
  end
end
