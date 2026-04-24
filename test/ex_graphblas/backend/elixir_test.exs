defmodule GraphBLAS.Backend.ElixirTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.Elixir, as: RefBackend
  alias GraphBLAS.{Matrix, Scalar, Vector}

  describe "matrix_new/4" do
    test "creates an empty matrix" do
      assert {:ok, %Matrix{} = m} = RefBackend.matrix_new(3, 3, :int64, [])
      assert {:ok, {3, 3}} = Matrix.shape(m)
      assert {:ok, 0} = Matrix.nvals(m)
    end

    test "rejects negative dimensions" do
      assert {:error, %GraphBLAS.Error{reason: {:invalid_argument, _}}} =
               RefBackend.matrix_new(-1, 3, :int64, [])
    end

    test "rejects unknown types" do
      assert {:error, {:unsupported_type, :bad}} =
               RefBackend.matrix_new(3, 3, :bad, [])
    end
  end

  describe "matrix_from_coo/5" do
    test "creates a matrix from COO triples" do
      entries = [{0, 1, 1}, {1, 2, 2}, {2, 0, 3}]
      assert {:ok, %Matrix{} = m} = RefBackend.matrix_from_coo(3, 3, entries, :int64, [])
      assert {:ok, {3, 3}} = Matrix.shape(m)
      assert {:ok, 3} = Matrix.nvals(m)
    end

    test "combines duplicate entries with additive monoid" do
      entries = [{0, 0, 1}, {0, 0, 2}]
      assert {:ok, m} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
      assert {:ok, coo} = Matrix.to_coo(m)
      assert [{0, 0, 3}] = coo
    end

    test "rejects out-of-bounds indices" do
      entries = [{5, 0, 1}]

      assert {:error, %GraphBLAS.Error{reason: {:index_out_of_bounds, 5, :row, 3}}} =
               RefBackend.matrix_from_coo(3, 3, entries, :int64, [])
    end

    test "creates identity matrix" do
      entries = [{0, 0, 1}, {1, 1, 1}, {2, 2, 1}]
      assert {:ok, m} = RefBackend.matrix_from_coo(3, 3, entries, :int64, [])
      assert {:ok, 3} = Matrix.nvals(m)
      assert {:ok, entries_sorted} = Matrix.to_coo(m)
      assert entries_sorted == entries
    end
  end

  describe "matrix_to_coo/1" do
    test "returns sorted entries" do
      entries = [{2, 0, 3}, {0, 1, 1}, {1, 2, 2}]
      assert {:ok, m} = RefBackend.matrix_from_coo(3, 3, entries, :int64, [])
      assert {:ok, coo} = Matrix.to_coo(m)
      assert coo == [{0, 1, 1}, {1, 2, 2}, {2, 0, 3}]
    end
  end

  describe "matrix_mxm/4" do
    test "multiplies two matrices with plus_times semiring" do
      entries_a = [{0, 1, 1}, {1, 2, 1}]
      entries_b = [{1, 0, 2}, {2, 1, 3}]

      assert {:ok, a} = RefBackend.matrix_from_coo(2, 3, entries_a, :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(3, 2, entries_b, :int64, [])
      assert {:ok, c} = RefBackend.matrix_mxm(a, b, :plus_times, [])

      assert {:ok, {2, 2}} = Matrix.shape(c)
      assert {:ok, coo} = Matrix.to_coo(c)
      # (0,1)*(1,0) = 1*2 = 2 => (0,0)
      # (1,2)*(2,1) = 1*3 = 3 => (1,1)
      assert {0, 0, 2} in coo
      assert {1, 1, 3} in coo
    end

    test "rejects dimension mismatch" do
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 3, [{0, 0, 1}], :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])

      assert {:error, %GraphBLAS.Error{reason: {:dimension_mismatch, _, _}}} =
               RefBackend.matrix_mxm(a, b, :plus_times, [])
    end
  end

  describe "matrix_mxv/4" do
    test "multiplies matrix by vector" do
      entries_m = [{0, 0, 1}, {0, 1, 1}]
      assert {:ok, m} = RefBackend.matrix_from_coo(1, 2, entries_m, :int64, [])
      assert {:ok, v} = RefBackend.vector_from_entries(2, [{0, 2}, {1, 3}], :int64, [])
      assert {:ok, result} = RefBackend.matrix_mxv(m, v, :plus_times, [])
      assert {:ok, entries} = Vector.to_entries(result)
      assert {0, 5} in entries
    end
  end

  describe "matrix_ewise_add/4" do
    test "adds two matrices element-wise" do
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 3}, {0, 1, 4}], :int64, [])
      assert {:ok, c} = RefBackend.matrix_ewise_add(a, b, :plus, [])
      assert {:ok, 3} = Matrix.nvals(c)
      assert {:ok, coo} = Matrix.to_coo(c)
      assert {0, 0, 4} in coo
      assert {0, 1, 4} in coo
      assert {1, 1, 2} in coo
    end

    test "rejects shape mismatch" do
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 1}], :int64, [])

      assert {:error, %GraphBLAS.Error{reason: {:dimension_mismatch, _, _}}} =
               RefBackend.matrix_ewise_add(a, b, :plus, [])
    end
  end

  describe "matrix_ewise_mult/4" do
    test "multiplies overlapping entries" do
      assert {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 2}, {0, 1, 3}], :int64, [])
      assert {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 4}, {1, 0, 5}], :int64, [])
      assert {:ok, c} = RefBackend.matrix_ewise_mult(a, b, :times, [])
      # Only (0,0) is in both
      assert {:ok, 1} = Matrix.nvals(c)
      assert {:ok, [{0, 0, 8}]} = Matrix.to_coo(c)
    end
  end

  describe "matrix_reduce/3" do
    test "reduces matrix rows to a vector" do
      entries = [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}]
      assert {:ok, m} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
      assert {:ok, v} = RefBackend.matrix_reduce(m, :plus, [])
      assert {:ok, entries_v} = Vector.to_entries(v)
      assert {0, 3} in entries_v
      assert {1, 3} in entries_v
    end
  end

  describe "matrix_transpose/2" do
    test "transposes a matrix" do
      entries = [{0, 1, 2}, {1, 0, 3}]
      assert {:ok, m} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
      assert {:ok, t} = RefBackend.matrix_transpose(m, [])
      assert {:ok, {2, 2}} = Matrix.shape(t)
      assert {:ok, coo} = Matrix.to_coo(t)
      assert {0, 1, 3} in coo
      assert {1, 0, 2} in coo
    end
  end

  describe "vector operations" do
    test "creates and inspects a vector" do
      assert {:ok, v} = RefBackend.vector_new(5, :int64, [])
      assert {:ok, 5} = Vector.size(v)
      assert {:ok, 0} = Vector.nvals(v)
      assert {:ok, :int64} = Vector.type(v)
    end

    test "creates a vector from entries" do
      assert {:ok, v} = RefBackend.vector_from_entries(4, [{0, 1}, {2, 3}], :int64, [])
      assert {:ok, 2} = Vector.nvals(v)
      assert {:ok, entries} = Vector.to_entries(v)
      assert [{0, 1}, {2, 3}] == entries
    end

    test "combines duplicate vector entries" do
      assert {:ok, v} = RefBackend.vector_from_entries(4, [{0, 1}, {0, 2}], :int64, [])
      assert {:ok, 1} = Vector.nvals(v)
      assert {:ok, [{0, 3}]} = Vector.to_entries(v)
    end

    test "rejects out-of-bounds vector indices" do
      assert {:error, %GraphBLAS.Error{reason: {:index_out_of_bounds, 5, :index, 4}}} =
               RefBackend.vector_from_entries(4, [{5, 1}], :int64, [])
    end
  end

  describe "vector_ewise_add/4" do
    test "adds two vectors element-wise" do
      assert {:ok, a} = RefBackend.vector_from_entries(3, [{0, 1}, {1, 2}], :int64, [])
      assert {:ok, b} = RefBackend.vector_from_entries(3, [{0, 3}, {2, 4}], :int64, [])
      assert {:ok, c} = RefBackend.vector_ewise_add(a, b, :plus, [])
      assert {:ok, entries} = Vector.to_entries(c)
      assert {0, 4} in entries
      assert {1, 2} in entries
      assert {2, 4} in entries
    end
  end

  describe "vector_ewise_mult/4" do
    test "multiplies overlapping entries" do
      assert {:ok, a} = RefBackend.vector_from_entries(3, [{0, 2}, {1, 3}], :int64, [])
      assert {:ok, b} = RefBackend.vector_from_entries(3, [{0, 4}, {1, 5}], :int64, [])
      assert {:ok, c} = RefBackend.vector_ewise_mult(a, b, :times, [])
      assert {:ok, entries} = Vector.to_entries(c)
      assert {0, 8} in entries
      assert {1, 15} in entries
    end
  end

  describe "vector_reduce/3" do
    test "reduces a vector to a scalar" do
      assert {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}, {1, 2}, {2, 3}], :int64, [])
      assert {:ok, scalar} = RefBackend.vector_reduce(v, :plus, [])
      assert %Scalar{type: :int64, value: 6} = scalar
    end

    test "reduces single-element vector" do
      assert {:ok, v} = RefBackend.vector_from_entries(3, [{1, 42}], :int64, [])
      assert {:ok, scalar} = RefBackend.vector_reduce(v, :plus, [])
      assert %Scalar{value: 42} = scalar
    end
  end

  describe "matrix_set/4" do
    test "sets a value at a position" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      {:ok, updated} = RefBackend.matrix_set(m, 1, 1, 5)
      {:ok, coo} = RefBackend.matrix_to_coo(updated)
      assert {1, 1, 5} in coo
    end

    test "overwrites existing value" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      {:ok, updated} = RefBackend.matrix_set(m, 0, 0, 42)
      {:ok, coo} = RefBackend.matrix_to_coo(updated)
      assert {0, 0, 42} in coo
      refute {0, 0, 1} in coo
    end

    test "rejects out-of-bounds row" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      assert {:error, %GraphBLAS.Error{}} = RefBackend.matrix_set(m, 5, 0, 1)
    end

    test "rejects out-of-bounds col" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      assert {:error, %GraphBLAS.Error{}} = RefBackend.matrix_set(m, 0, 5, 1)
    end

    test "sets bool value" do
      {:ok, m} = RefBackend.matrix_new(2, 2, :bool, [])
      {:ok, updated} = RefBackend.matrix_set(m, 0, 0, true)
      {:ok, coo} = RefBackend.matrix_to_coo(updated)
      assert {0, 0, true} in coo
    end

    test "sets fp64 value" do
      {:ok, m} = RefBackend.matrix_new(2, 2, :fp64, [])
      {:ok, updated} = RefBackend.matrix_set(m, 1, 0, 3.14)
      {:ok, coo} = RefBackend.matrix_to_coo(updated)
      assert {1, 0, 3.14} in coo
    end
  end

  describe "matrix_extract/3" do
    test "extracts a stored value" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 42}], :int64, [])
      assert {:ok, 42} = RefBackend.matrix_extract(m, 0, 0)
    end

    test "returns default for structural zero (int64)" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 42}], :int64, [])
      assert {:ok, 0} = RefBackend.matrix_extract(m, 1, 1)
    end

    test "returns default for structural zero (bool)" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, true}], :bool, [])
      assert {:ok, false} = RefBackend.matrix_extract(m, 1, 1)
    end

    test "returns default for structural zero (fp64)" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1.5}], :fp64, [])
      assert {:ok, +0.0} = RefBackend.matrix_extract(m, 1, 1)
    end

    test "rejects out-of-bounds row" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      assert {:error, %GraphBLAS.Error{}} = RefBackend.matrix_extract(m, 5, 0)
    end
  end

  describe "matrix_dup/1" do
    test "creates an independent copy" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      {:ok, copy} = RefBackend.matrix_dup(m)

      {:ok, coo_orig} = RefBackend.matrix_to_coo(m)
      {:ok, coo_copy} = RefBackend.matrix_to_coo(copy)
      assert coo_orig == coo_copy

      {:ok, modified} = RefBackend.matrix_set(copy, 0, 0, 99)
      {:ok, coo_modified} = RefBackend.matrix_to_coo(modified)
      assert {0, 0, 99} in coo_modified

      {:ok, coo_orig_still} = RefBackend.matrix_to_coo(m)
      assert {0, 0, 1} in coo_orig_still
    end
  end

  describe "vector_set/3" do
    test "sets a value at an index" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      {:ok, updated} = RefBackend.vector_set(v, 1, 5)
      {:ok, entries} = RefBackend.vector_to_entries(updated)
      assert {1, 5} in entries
    end

    test "overwrites existing value" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      {:ok, updated} = RefBackend.vector_set(v, 0, 42)
      {:ok, entries} = RefBackend.vector_to_entries(updated)
      assert {0, 42} in entries
    end

    test "rejects out-of-bounds index" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      assert {:error, %GraphBLAS.Error{}} = RefBackend.vector_set(v, 5, 1)
    end

    test "sets bool value" do
      {:ok, v} = RefBackend.vector_new(3, :bool, [])
      {:ok, updated} = RefBackend.vector_set(v, 1, true)
      {:ok, entries} = RefBackend.vector_to_entries(updated)
      assert {1, true} in entries
    end
  end

  describe "vector_extract/2" do
    test "extracts a stored value" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 42}], :int64, [])
      assert {:ok, 42} = RefBackend.vector_extract(v, 0)
    end

    test "returns default for structural zero (int64)" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 42}], :int64, [])
      assert {:ok, 0} = RefBackend.vector_extract(v, 1)
    end

    test "returns default for structural zero (fp64)" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1.5}], :fp64, [])
      assert {:ok, +0.0} = RefBackend.vector_extract(v, 1)
    end

    test "returns default for structural zero (bool)" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, true}], :bool, [])
      assert {:ok, false} = RefBackend.vector_extract(v, 1)
    end

    test "rejects out-of-bounds index" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      assert {:error, %GraphBLAS.Error{}} = RefBackend.vector_extract(v, 5)
    end
  end

  describe "vector_dup/1" do
    test "creates an independent copy" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      {:ok, copy} = RefBackend.vector_dup(v)

      {:ok, entries_orig} = RefBackend.vector_to_entries(v)
      {:ok, entries_copy} = RefBackend.vector_to_entries(copy)
      assert entries_orig == entries_copy

      {:ok, modified} = RefBackend.vector_set(copy, 0, 99)
      {:ok, entries_modified} = RefBackend.vector_to_entries(modified)
      assert {0, 99} in entries_modified

      {:ok, entries_orig_still} = RefBackend.vector_to_entries(v)
      assert {0, 1} in entries_orig_still
    end
  end

  describe "vector_vxm/4" do
    test "multiplies vector by matrix from left" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}, {2, 2}], :int64, [])
      {:ok, m} = RefBackend.matrix_from_coo(3, 2, [{0, 0, 3}, {2, 1, 4}], :int64, [])
      {:ok, result} = RefBackend.vector_vxm(v, m, :plus_times, [])
      assert {:ok, 2} = Vector.size(result)
    end

    test "rejects dimension mismatch" do
      {:ok, v} = RefBackend.vector_from_entries(2, [{0, 1}], :int64, [])
      {:ok, m} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 1}], :int64, [])

      assert {:error, %GraphBLAS.Error{reason: {:dimension_mismatch, _, _}}} =
               RefBackend.vector_vxm(v, m, :plus_times, [])
    end
  end

  describe "vector size mismatch errors" do
    test "vector_ewise_add rejects size mismatch" do
      {:ok, a} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      {:ok, b} = RefBackend.vector_from_entries(4, [{0, 2}], :int64, [])

      assert {:error, %GraphBLAS.Error{reason: {:dimension_mismatch, 4, 3}}} =
               RefBackend.vector_ewise_add(a, b, :plus, [])
    end

    test "vector_ewise_mult rejects size mismatch" do
      {:ok, a} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      {:ok, b} = RefBackend.vector_from_entries(5, [{0, 2}], :int64, [])

      assert {:error, %GraphBLAS.Error{reason: {:dimension_mismatch, 5, 3}}} =
               RefBackend.vector_ewise_mult(a, b, :times, [])
    end
  end

  describe "mask type mismatch errors" do
    test "matrix operation with vector mask returns error" do
      {:ok, m1} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      {:ok, m2} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 2}], :int64, [])
      {:ok, v_mask} = RefBackend.vector_from_entries(2, [{0, true}], :bool, [])
      mask = GraphBLAS.Mask.new(v_mask)

      assert {:error, %GraphBLAS.Error{reason: {:mask_type_mismatch, :vector, :matrix}}} =
               RefBackend.matrix_mxm(m1, m2, :plus_times, mask: mask)
    end

    test "vector operation with matrix mask returns error" do
      {:ok, v1} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      {:ok, v2} = RefBackend.vector_from_entries(3, [{0, 2}], :int64, [])
      {:ok, m_mask} = RefBackend.matrix_from_coo(3, 3, [{0, 0, true}], :bool, [])
      mask = GraphBLAS.Mask.new(m_mask)

      assert {:error, %GraphBLAS.Error{reason: {:mask_type_mismatch, :matrix, :vector}}} =
               RefBackend.vector_ewise_add(v1, v2, :plus, mask: mask)
    end

    test "matrix_ewise_add with vector mask returns error" do
      {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 2}], :int64, [])
      {:ok, v_mask} = RefBackend.vector_from_entries(2, [{0, true}], :bool, [])
      mask = GraphBLAS.Mask.new(v_mask)

      assert {:error, %GraphBLAS.Error{reason: {:mask_type_mismatch, :vector, :matrix}}} =
               RefBackend.matrix_ewise_add(a, b, :plus, mask: mask)
    end

    test "matrix_transpose with vector mask returns error" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 1, 1}], :int64, [])
      {:ok, v_mask} = RefBackend.vector_from_entries(2, [{0, true}], :bool, [])
      mask = GraphBLAS.Mask.new(v_mask)

      assert {:error, %GraphBLAS.Error{reason: {:mask_type_mismatch, :vector, :matrix}}} =
               RefBackend.matrix_transpose(m, mask: mask)
    end

    test "vector_vxm with matrix mask returns error" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      {:ok, m} = RefBackend.matrix_from_coo(3, 2, [{0, 0, 1}], :int64, [])
      {:ok, m_mask} = RefBackend.matrix_from_coo(2, 2, [{0, 0, true}], :bool, [])
      mask = GraphBLAS.Mask.new(m_mask)

      assert {:error, %GraphBLAS.Error{reason: {:mask_type_mismatch, :matrix, :vector}}} =
               RefBackend.vector_vxm(v, m, :plus_times, mask: mask)
    end
  end

  describe "empty container edge cases" do
    test "mxm on empty matrices" do
      {:ok, a} = RefBackend.matrix_from_coo(2, 2, [], :int64, [])
      {:ok, b} = RefBackend.matrix_from_coo(2, 2, [], :int64, [])
      {:ok, c} = RefBackend.matrix_mxm(a, b, :plus_times, [])
      assert {:ok, 0} = Matrix.nvals(c)
    end

    test "mxv on empty matrix" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 3, [], :int64, [])
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      {:ok, result} = RefBackend.matrix_mxv(m, v, :plus_times, [])
      assert {:ok, 0} = Vector.nvals(result)
    end

    test "vector_reduce on empty vector" do
      {:ok, v} = RefBackend.vector_from_entries(3, [], :int64, [])
      {:ok, scalar} = RefBackend.vector_reduce(v, :plus, [])
      assert %Scalar{value: 0} = scalar
    end

    test "matrix_reduce on empty matrix" do
      {:ok, m} = RefBackend.matrix_from_coo(3, 3, [], :int64, [])
      {:ok, v} = RefBackend.matrix_reduce(m, :plus, [])
      assert {:ok, 0} = Vector.nvals(v)
    end
  end

  describe "matrix_mxv/4 with mxv dimension checks" do
    test "rejects dimension mismatch" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 3, [{0, 0, 1}], :int64, [])
      {:ok, v} = RefBackend.vector_from_entries(2, [{0, 1}], :int64, [])

      assert {:error, %GraphBLAS.Error{reason: {:dimension_mismatch, {3, 2}, _}}} =
               RefBackend.matrix_mxv(m, v, :plus_times, [])
    end
  end

  describe "matrix_to_dense/1" do
    test "converts empty matrix to dense" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [], :int64, [])
      {:ok, dense} = RefBackend.matrix_to_dense(m)
      assert dense == [[0, 0], [0, 0]]
    end

    test "converts bool matrix to dense" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, true}, {1, 1, true}], :bool, [])
      {:ok, dense} = RefBackend.matrix_to_dense(m)
      assert dense == [[true, false], [false, true]]
    end
  end

  describe "vector_to_list/1" do
    test "converts empty vector to list" do
      {:ok, v} = RefBackend.vector_from_entries(3, [], :int64, [])
      {:ok, list} = RefBackend.vector_to_list(v)
      assert list == [0, 0, 0]
    end

    test "converts bool vector to list" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, true}, {2, true}], :bool, [])
      {:ok, list} = RefBackend.vector_to_list(v)
      assert list == [true, false, true]
    end
  end

  describe "vector_size/1" do
    test "returns the size of a vector" do
      {:ok, v} = RefBackend.vector_from_entries(10, [{0, 1}, {5, 2}], :int64, [])
      assert {:ok, 10} = RefBackend.vector_size(v)
    end

    test "returns size for empty vector" do
      {:ok, v} = RefBackend.vector_new(7, :int64, [])
      assert {:ok, 7} = RefBackend.vector_size(v)
    end
  end

  describe "vector_type/1" do
    test "returns the type of an int64 vector" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      assert {:ok, :int64} = RefBackend.vector_type(v)
    end

    test "returns the type of a fp64 vector" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, 1.5}], :fp64, [])
      assert {:ok, :fp64} = RefBackend.vector_type(v)
    end

    test "returns the type of a bool vector" do
      {:ok, v} = RefBackend.vector_from_entries(3, [{0, true}], :bool, [])
      assert {:ok, :bool} = RefBackend.vector_type(v)
    end
  end

  describe "mask with :value mode (tests get_matrix_mask_positions :value path)" do
    test "matrix operation with value mask filters by non-zero values" do
      {:ok, m1} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 1}, {1, 1, 2}, {2, 2, 3}], :int64, [])
      {:ok, m2} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 5}, {1, 1, 10}], :int64, [])

      {:ok, mask_m} =
        RefBackend.matrix_from_coo(3, 3, [{0, 0, 1}, {1, 1, 0}, {2, 2, 5}], :int64, [])

      mask = GraphBLAS.Mask.new(mask_m)
      descriptor = GraphBLAS.Descriptor.new(mask: :value)

      {:ok, result} =
        RefBackend.matrix_ewise_add(m1, m2, :plus, mask: mask, descriptor: descriptor)

      {:ok, coo} = Matrix.to_coo(result)

      assert {0, 0, 6} in coo
      assert {2, 2, 3} in coo
      refute Enum.any?(coo, fn {r, c, _} -> r == 1 and c == 1 end)
    end

    test "matrix operation with value mask filters false values in bool mask" do
      {:ok, m1} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64, [])
      {:ok, m2} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 3}, {1, 1, 4}], :int64, [])
      {:ok, mask_m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, true}, {1, 1, false}], :bool, [])

      mask = GraphBLAS.Mask.new(mask_m)
      descriptor = GraphBLAS.Descriptor.new(mask: :value)

      {:ok, result} =
        RefBackend.matrix_ewise_add(m1, m2, :plus, mask: mask, descriptor: descriptor)

      {:ok, coo} = Matrix.to_coo(result)
      assert [{0, 0, 4}] = coo
    end

    test "matrix operation with value mask filters 0.0 in fp64 mask" do
      {:ok, m1} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1.0}, {1, 1, 2.0}], :fp64, [])
      {:ok, m2} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 3.0}, {1, 1, 4.0}], :fp64, [])
      {:ok, mask_m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1.5}, {1, 1, 0.0}], :fp64, [])

      mask = GraphBLAS.Mask.new(mask_m)
      descriptor = GraphBLAS.Descriptor.new(mask: :value)

      {:ok, result} =
        RefBackend.matrix_ewise_add(m1, m2, :plus, mask: mask, descriptor: descriptor)

      {:ok, coo} = Matrix.to_coo(result)
      assert [{0, 0, 4.0}] = coo
    end
  end
end
