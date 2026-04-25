if System.get_env("EX_GRAPHBLAS_COMPILE_NATIVE") in ["1", "true"] do
  defmodule GraphBLAS.SuiteSparseBackendTest do
    use ExUnit.Case, async: false

    @moduletag :native_backend

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

    describe "matrix_mxm with other semirings" do
      test "plus_min/int64: multiply two matrices" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 5}, {1, 2, 3}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(3, 2, [{1, 0, 2}, {2, 1, 4}], :int64, [])
        {:ok, c} = SuiteSparse.matrix_mxm(a, b, :plus_min, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        refute coo == []
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "max_plus/int64: multiply two matrices" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 2}, {1, 2, 3}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(3, 2, [{1, 0, 1}, {2, 1, 4}], :int64, [])
        {:ok, c} = SuiteSparse.matrix_mxm(a, b, :max_plus, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        refute coo == []
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "max_min/int64: multiply two matrices" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 5}, {1, 2, 3}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(3, 2, [{1, 0, 2}, {2, 1, 4}], :int64, [])
        {:ok, c} = SuiteSparse.matrix_mxm(a, b, :max_min, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        refute coo == []
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "lor_land/bool: boolean adjacency multiplication" do
        {:ok, a} = SuiteSparse.matrix_from_coo(3, 3, [{0, 1, true}, {1, 2, true}], :bool, [])
        {:ok, c} = SuiteSparse.matrix_mxm(a, a, :lor_land, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert {0, 2, true} in coo
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(c)
      end

      test "land_lor/bool: dual boolean semiring multiplication" do
        {:ok, a} = SuiteSparse.matrix_from_coo(3, 3, [{0, 1, true}, {1, 2, true}], :bool, [])
        {:ok, c} = SuiteSparse.matrix_mxm(a, a, :land_lor, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert is_list(coo)
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(c)
      end

      test "plus_times_fp64: multiply two fp64 matrices" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 1.5}, {1, 2, 2.5}], :fp64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(3, 2, [{1, 0, 2.0}, {2, 1, 3.0}], :fp64, [])
        {:ok, c} = SuiteSparse.matrix_mxm(a, b, :plus_times_fp64, [])
        {:ok, nvals} = SuiteSparse.matrix_nvals(c)
        assert nvals > 0
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end
    end

    describe "matrix_ewise with other monoids" do
      test "ewise_add with :times monoid (int64)" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 2}, {1, 1, 3}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 4}, {1, 1, 5}], :int64, [])
        {:ok, c} = SuiteSparse.matrix_ewise_add(a, b, :times, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert {0, 0, 8} in coo
        assert {1, 1, 15} in coo
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "ewise_add with :min monoid (int64)" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 5}, {1, 1, 2}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 3}, {1, 1, 7}], :int64, [])
        {:ok, c} = SuiteSparse.matrix_ewise_add(a, b, :min, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert {0, 0, 3} in coo
        assert {1, 1, 2} in coo
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "ewise_add with :max monoid (int64)" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 5}, {1, 1, 2}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 3}, {1, 1, 7}], :int64, [])
        {:ok, c} = SuiteSparse.matrix_ewise_add(a, b, :max, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert {0, 0, 5} in coo
        assert {1, 1, 7} in coo
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "ewise_add with :lor monoid (bool)" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, true}, {1, 1, false}], :bool, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, false}, {1, 1, true}], :bool, [])
        {:ok, c} = SuiteSparse.matrix_ewise_add(a, b, :lor, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert {0, 0, true} in coo
        assert {1, 1, true} in coo
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "ewise_mult with :min monoid (int64)" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 5}, {1, 1, 2}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 3}, {1, 1, 7}], :int64, [])
        {:ok, c} = SuiteSparse.matrix_ewise_mult(a, b, :min, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert {0, 0, 3} in coo
        assert {1, 1, 2} in coo
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "ewise_mult with :max monoid (int64)" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 5}, {1, 1, 2}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 3}, {1, 1, 7}], :int64, [])
        {:ok, c} = SuiteSparse.matrix_ewise_mult(a, b, :max, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert {0, 0, 5} in coo
        assert {1, 1, 7} in coo
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "ewise_mult with :land monoid (bool)" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, true}, {1, 1, true}], :bool, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, true}, {1, 1, false}], :bool, [])
        {:ok, c} = SuiteSparse.matrix_ewise_mult(a, b, :land, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)
        assert {0, 0, true} in coo
        assert {1, 1, false} in coo
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end
    end

    describe "matrix_reduce with other monoids" do
      test "reduce with :times monoid (int64)" do
        {:ok, m} =
          SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 2}, {0, 1, 3}, {1, 1, 4}], :int64, [])

        {:ok, v} = SuiteSparse.matrix_reduce(m, :times, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(v)
        assert {0, 6} in entries
        assert {1, 4} in entries
        SuiteSparse.matrix_free(m)
        SuiteSparse.vector_free(v)
      end

      test "reduce with :min monoid (int64)" do
        {:ok, m} =
          SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 5}, {0, 1, 2}, {1, 0, 3}], :int64, [])

        {:ok, v} = SuiteSparse.matrix_reduce(m, :min, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(v)
        assert {0, 2} in entries
        assert {1, 3} in entries
        SuiteSparse.matrix_free(m)
        SuiteSparse.vector_free(v)
      end

      test "reduce with :max monoid (int64)" do
        {:ok, m} =
          SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 5}, {0, 1, 2}, {1, 0, 3}], :int64, [])

        {:ok, v} = SuiteSparse.matrix_reduce(m, :max, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(v)
        assert {0, 5} in entries
        assert {1, 3} in entries
        SuiteSparse.matrix_free(m)
        SuiteSparse.vector_free(v)
      end

      test "reduce with :lor monoid (bool)" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, true}, {1, 1, false}], :bool, [])
        {:ok, v} = SuiteSparse.matrix_reduce(m, :lor, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(v)
        assert {0, true} in entries
        assert {1, false} in entries
        SuiteSparse.matrix_free(m)
        SuiteSparse.vector_free(v)
      end
    end

    describe "matrix_transpose with all types" do
      test "transpose fp64 matrix" do
        entries = [{0, 1, 1.5}, {1, 0, 2.5}]
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, entries, :fp64, [])
        {:ok, t} = SuiteSparse.matrix_transpose(m, [])
        {:ok, result} = SuiteSparse.matrix_to_coo(t)
        sorted = Enum.sort_by(result, fn {r, c, _v} -> {r, c} end)
        assert {0, 1, 2.5} in sorted
        assert {1, 0, 1.5} in sorted
        SuiteSparse.matrix_free(m)
        SuiteSparse.matrix_free(t)
      end

      test "transpose bool matrix" do
        entries = [{0, 1, true}, {1, 0, true}]
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, entries, :bool, [])
        {:ok, t} = SuiteSparse.matrix_transpose(m, [])
        {:ok, result} = SuiteSparse.matrix_to_coo(t)
        sorted = Enum.sort_by(result, fn {r, c, _v} -> {r, c} end)
        assert sorted == [{0, 1, true}, {1, 0, true}]
        SuiteSparse.matrix_free(m)
        SuiteSparse.matrix_free(t)
      end

      test "transpose non-square matrix" do
        entries = [{0, 2, 7}]
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 3, entries, :int64, [])
        {:ok, t} = SuiteSparse.matrix_transpose(m, [])
        assert {:ok, {3, 2}} = SuiteSparse.matrix_shape(t)
        {:ok, result} = SuiteSparse.matrix_to_coo(t)
        assert [{2, 0, 7}] == result
        SuiteSparse.matrix_free(m)
        SuiteSparse.matrix_free(t)
      end
    end

    describe "mxv and vxm" do
      test "matrix_mxv with plus_times" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 1}, {1, 2, 2}], :int64, [])
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{1, 3}, {2, 4}], :int64, [])
        {:ok, r} = SuiteSparse.matrix_mxv(m, v, :plus_times, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(r)
        assert {0, 3} in entries
        assert {1, 8} in entries
        SuiteSparse.matrix_free(m)
        SuiteSparse.vector_free(v)
        SuiteSparse.vector_free(r)
      end

      test "matrix_mxv with lor_land (bool)" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, true}, {1, 2, true}], :bool, [])
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{1, true}, {2, true}], :bool, [])
        {:ok, r} = SuiteSparse.matrix_mxv(m, v, :lor_land, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(r)
        assert {0, true} in entries
        assert {1, true} in entries
        SuiteSparse.matrix_free(m)
        SuiteSparse.vector_free(v)
        SuiteSparse.vector_free(r)
      end

      test "vector_vxm with plus_times" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1}, {2, 2}], :int64, [])
        {:ok, m} = SuiteSparse.matrix_from_coo(3, 2, [{0, 0, 3}, {2, 1, 4}], :int64, [])
        {:ok, r} = SuiteSparse.vector_vxm(v, m, :plus_times, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(r)
        assert {0, 3} in entries
        assert {1, 8} in entries
        SuiteSparse.vector_free(v)
        SuiteSparse.matrix_free(m)
        SuiteSparse.vector_free(r)
      end
    end

    describe "vector operations with all types" do
      test "creates fp64 vector and extracts entries" do
        {:ok, v} = SuiteSparse.vector_from_entries(4, [{0, 1.5}, {2, 3.5}], :fp64, [])
        assert {:ok, 2} = SuiteSparse.vector_nvals(v)
        assert {:ok, 4} = SuiteSparse.vector_size(v)
        {:ok, entries} = SuiteSparse.vector_to_entries(v)
        assert {0, 1.5} in entries
        assert {2, 3.5} in entries
        SuiteSparse.vector_free(v)
      end

      test "creates bool vector and extracts entries" do
        {:ok, v} = SuiteSparse.vector_from_entries(4, [{0, true}, {2, false}], :bool, [])
        assert {:ok, 2} = SuiteSparse.vector_nvals(v)
        assert {:ok, 4} = SuiteSparse.vector_size(v)
        {:ok, entries} = SuiteSparse.vector_to_entries(v)
        assert {0, true} in entries
        assert {2, false} in entries
        SuiteSparse.vector_free(v)
      end

      test "element-wise addition of two fp64 vectors" do
        {:ok, a} = SuiteSparse.vector_from_entries(3, [{0, 1.5}, {1, 2.5}], :fp64, [])
        {:ok, b} = SuiteSparse.vector_from_entries(3, [{0, 3.5}, {1, 4.5}], :fp64, [])
        {:ok, c} = SuiteSparse.vector_ewise_add(a, b, :plus_fp64, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(c)
        assert {0, 5.0} in entries
        assert {1, 7.0} in entries
        SuiteSparse.vector_free(a)
        SuiteSparse.vector_free(b)
        SuiteSparse.vector_free(c)
      end

      test "element-wise addition of two bool vectors with :lor" do
        {:ok, a} = SuiteSparse.vector_from_entries(3, [{0, true}, {1, false}], :bool, [])
        {:ok, b} = SuiteSparse.vector_from_entries(3, [{0, false}, {1, true}], :bool, [])
        {:ok, c} = SuiteSparse.vector_ewise_add(a, b, :lor, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(c)
        assert {0, true} in entries
        assert {1, true} in entries
        SuiteSparse.vector_free(a)
        SuiteSparse.vector_free(b)
        SuiteSparse.vector_free(c)
      end

      test "element-wise mult of two bool vectors with :land" do
        {:ok, a} = SuiteSparse.vector_from_entries(3, [{0, true}, {1, true}], :bool, [])
        {:ok, b} = SuiteSparse.vector_from_entries(3, [{0, true}, {1, false}], :bool, [])
        {:ok, c} = SuiteSparse.vector_ewise_mult(a, b, :land, [])
        {:ok, entries} = SuiteSparse.vector_to_entries(c)
        assert {0, true} in entries
        assert {1, false} in entries
        SuiteSparse.vector_free(a)
        SuiteSparse.vector_free(b)
        SuiteSparse.vector_free(c)
      end

      test "reduces a fp64 vector to a scalar" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1.5}, {1, 2.5}, {2, 3.0}], :fp64, [])
        {:ok, scalar} = SuiteSparse.vector_reduce(v, :plus_fp64, [])
        assert_in_delta scalar.value, 7.0, 0.001
        SuiteSparse.vector_free(v)
      end

      test "reduces a bool vector with :lor" do
        {:ok, v} =
          SuiteSparse.vector_from_entries(3, [{0, true}, {1, false}, {2, true}], :bool, [])

        {:ok, scalar} = SuiteSparse.vector_reduce(v, :lor, [])
        assert scalar.value == true
        SuiteSparse.vector_free(v)
      end

      test "reduces a bool vector with :land" do
        {:ok, v} =
          SuiteSparse.vector_from_entries(3, [{0, true}, {1, true}, {2, true}], :bool, [])

        {:ok, scalar} = SuiteSparse.vector_reduce(v, :land, [])
        assert scalar.value == true
        SuiteSparse.vector_free(v)
      end
    end

    describe "error paths" do
      test "unsupported type :fp32 returns error" do
        assert {:error, %GraphBLAS.Error{reason: {:unsupported_type, :fp32}}} =
                 SuiteSparse.matrix_new(3, 3, :fp32, [])
      end

      test "unsupported type :int8 returns error" do
        assert {:error, %GraphBLAS.Error{reason: {:unsupported_type, :int8}}} =
                 SuiteSparse.matrix_new(3, 3, :int8, [])
      end

      test "unsupported type for vector_new" do
        assert {:error, %GraphBLAS.Error{reason: {:unsupported_type, :int32}}} =
                 SuiteSparse.vector_new(3, :int32, [])
      end

      test "unknown semiring returns error via mxm" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        result = SuiteSparse.matrix_mxm(a, b, :nonexistent_semiring, [])
        assert match?({:error, _}, result)
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
      end

      test "unknown monoid returns error via ewise_add" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        result = SuiteSparse.matrix_ewise_add(a, b, :nonexistent_monoid, [])
        assert match?({:error, _}, result)
        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
      end

      test "negative dimension returns error" do
        result = SuiteSparse.matrix_new(-1, 3, :int64, [])
        assert match?({:error, _}, result)
      end

      test "negative ncols returns error" do
        result = SuiteSparse.matrix_new(3, -1, :int64, [])
        assert match?({:error, _}, result)
      end
    end

    describe "matrix_to_dense" do
      test "converts int64 matrix to dense" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 5}, {1, 1, 7}], :int64, [])
        {:ok, dense} = SuiteSparse.matrix_to_dense(m)
        assert dense == [[5, 0], [0, 7]]
        SuiteSparse.matrix_free(m)
      end

      test "converts bool matrix to dense" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, true}, {1, 1, true}], :bool, [])
        {:ok, dense} = SuiteSparse.matrix_to_dense(m)
        assert dense == [[true, false], [false, true]]
        SuiteSparse.matrix_free(m)
      end

      test "converts fp64 matrix to dense" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 1.5}, {1, 2, 2.5}], :fp64, [])
        {:ok, dense} = SuiteSparse.matrix_to_dense(m)
        assert dense == [[0.0, 1.5, 0.0], [0.0, 0.0, 2.5]]
        SuiteSparse.matrix_free(m)
      end

      test "converts empty matrix to all-zeros dense" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 3, [], :int64, [])
        {:ok, dense} = SuiteSparse.matrix_to_dense(m)
        assert dense == [[0, 0, 0], [0, 0, 0]]
        SuiteSparse.matrix_free(m)
      end

      test "converts 1x1 matrix to dense" do
        {:ok, m} = SuiteSparse.matrix_from_coo(1, 1, [{0, 0, 42}], :int64, [])
        {:ok, dense} = SuiteSparse.matrix_to_dense(m)
        assert dense == [[42]]
        SuiteSparse.matrix_free(m)
      end
    end

    describe "vector_to_list" do
      test "converts int64 vector to dense list" do
        {:ok, v} = SuiteSparse.vector_from_entries(4, [{0, 5}, {2, 3}], :int64, [])
        {:ok, list} = SuiteSparse.vector_to_list(v)
        assert list == [5, 0, 3, 0]
        SuiteSparse.vector_free(v)
      end

      test "converts bool vector to dense list" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, true}, {2, true}], :bool, [])
        {:ok, list} = SuiteSparse.vector_to_list(v)
        assert list == [true, false, true]
        SuiteSparse.vector_free(v)
      end

      test "converts fp64 vector to dense list" do
        {:ok, v} = SuiteSparse.vector_from_entries(4, [{0, 1.5}, {2, 3.5}], :fp64, [])
        {:ok, list} = SuiteSparse.vector_to_list(v)
        assert list == [1.5, 0.0, 3.5, 0.0]
        SuiteSparse.vector_free(v)
      end

      test "converts empty vector to all-defaults list" do
        {:ok, v} = SuiteSparse.vector_new(3, :int64, [])
        {:ok, list} = SuiteSparse.vector_to_list(v)
        assert list == [0, 0, 0]
        SuiteSparse.vector_free(v)
      end

      test "converts empty fp64 vector to all-zeros list" do
        {:ok, v} = SuiteSparse.vector_new(2, :fp64, [])
        {:ok, list} = SuiteSparse.vector_to_list(v)
        assert list == [0.0, 0.0]
        SuiteSparse.vector_free(v)
      end

      test "converts empty bool vector to all-false list" do
        {:ok, v} = SuiteSparse.vector_new(2, :bool, [])
        {:ok, list} = SuiteSparse.vector_to_list(v)
        assert list == [false, false]
        SuiteSparse.vector_free(v)
      end
    end

    describe "vector_new" do
      test "creates an empty vector" do
        {:ok, v} = SuiteSparse.vector_new(5, :int64, [])
        assert {:ok, 5} = SuiteSparse.vector_size(v)
        assert {:ok, 0} = SuiteSparse.vector_nvals(v)
        SuiteSparse.vector_free(v)
      end

      test "creates empty fp64 vector" do
        {:ok, v} = SuiteSparse.vector_new(3, :fp64, [])
        assert {:ok, :fp64} = SuiteSparse.vector_type(v)
        assert {:ok, 0} = SuiteSparse.vector_nvals(v)
        SuiteSparse.vector_free(v)
      end

      test "creates empty bool vector" do
        {:ok, v} = SuiteSparse.vector_new(3, :bool, [])
        assert {:ok, :bool} = SuiteSparse.vector_type(v)
        assert {:ok, 0} = SuiteSparse.vector_nvals(v)
        SuiteSparse.vector_free(v)
      end

      test "rejects unsupported type :int32" do
        assert {:error, %GraphBLAS.Error{reason: {:unsupported_type, :int32}}} =
                 SuiteSparse.vector_new(3, :int32, [])
      end

      test "rejects unsupported type :fp32" do
        assert {:error, %GraphBLAS.Error{reason: {:unsupported_type, :fp32}}} =
                 SuiteSparse.vector_new(3, :fp32, [])
      end

      test "empty vector to_entries returns empty list" do
        {:ok, v} = SuiteSparse.vector_new(3, :int64, [])
        assert {:ok, []} = SuiteSparse.vector_to_entries(v)
        SuiteSparse.vector_free(v)
      end
    end

    describe "empty matrix and vector operations" do
      test "empty matrix nvals is zero" do
        {:ok, m} = SuiteSparse.matrix_from_coo(5, 5, [], :int64, [])
        assert {:ok, 0} = SuiteSparse.matrix_nvals(m)
        SuiteSparse.matrix_free(m)
      end

      test "empty matrix to_coo returns empty list" do
        {:ok, m} = SuiteSparse.matrix_from_coo(5, 5, [], :int64, [])
        {:ok, coo} = SuiteSparse.matrix_to_coo(m)
        assert coo == []
        SuiteSparse.matrix_free(m)
      end

      test "empty vector nvals is zero" do
        {:ok, v} = SuiteSparse.vector_from_entries(5, [], :int64, [])
        assert {:ok, 0} = SuiteSparse.vector_nvals(v)
        SuiteSparse.vector_free(v)
      end

      test "empty vector reduce with :plus returns 0" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [], :int64, [])
        {:ok, scalar} = SuiteSparse.vector_reduce(v, :plus, [])
        assert scalar.value == 0
        SuiteSparse.vector_free(v)
      end

      test "empty vector reduce with :times returns 1" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [], :int64, [])
        {:ok, scalar} = SuiteSparse.vector_reduce(v, :times, [])
        assert scalar.value == 1
        SuiteSparse.vector_free(v)
      end

      test "empty vector reduce with :lor returns false" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [], :bool, [])
        {:ok, scalar} = SuiteSparse.vector_reduce(v, :lor, [])
        assert scalar.value == false
        SuiteSparse.vector_free(v)
      end

      test "empty vector reduce with :land returns true" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [], :bool, [])
        {:ok, scalar} = SuiteSparse.vector_reduce(v, :land, [])
        assert scalar.value == true
        SuiteSparse.vector_free(v)
      end
    end

    describe "matrix_set" do
      test "sets an int64 value" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        {:ok, updated} = SuiteSparse.matrix_set(m, 1, 1, 5)
        {:ok, coo} = SuiteSparse.matrix_to_coo(updated)
        assert {1, 1, 5} in coo
        SuiteSparse.matrix_free(updated)
      end

      test "sets a fp64 value" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [], :fp64, [])
        {:ok, updated} = SuiteSparse.matrix_set(m, 0, 1, 3.14)
        {:ok, coo} = SuiteSparse.matrix_to_coo(updated)
        assert {0, 1, 3.14} in coo
        SuiteSparse.matrix_free(updated)
      end

      test "sets a bool value" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [], :bool, [])
        {:ok, updated} = SuiteSparse.matrix_set(m, 0, 0, true)
        {:ok, coo} = SuiteSparse.matrix_to_coo(updated)
        assert {0, 0, true} in coo
        SuiteSparse.matrix_free(updated)
      end

      test "overwrites existing value" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        {:ok, updated} = SuiteSparse.matrix_set(m, 0, 0, 42)
        {:ok, coo} = SuiteSparse.matrix_to_coo(updated)
        assert {0, 0, 42} in coo
        refute {0, 0, 1} in coo
        SuiteSparse.matrix_free(updated)
      end

      test "rejects out-of-bounds row" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        assert {:error, %GraphBLAS.Error{}} = SuiteSparse.matrix_set(m, 5, 0, 1)
        SuiteSparse.matrix_free(m)
      end

      test "rejects out-of-bounds col" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        assert {:error, %GraphBLAS.Error{}} = SuiteSparse.matrix_set(m, 0, 5, 1)
        SuiteSparse.matrix_free(m)
      end
    end

    describe "matrix_extract" do
      test "extracts a stored int64 value" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 42}], :int64, [])
        assert {:ok, 42} = SuiteSparse.matrix_extract(m, 0, 0)
        SuiteSparse.matrix_free(m)
      end

      test "returns default for structural zero (int64)" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 42}], :int64, [])
        assert {:ok, 0} = SuiteSparse.matrix_extract(m, 1, 1)
        SuiteSparse.matrix_free(m)
      end

      test "returns default for structural zero (fp64)" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1.5}], :fp64, [])
        assert {:ok, +0.0} = SuiteSparse.matrix_extract(m, 1, 1)
        SuiteSparse.matrix_free(m)
      end

      test "returns default for structural zero (bool)" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, true}], :bool, [])
        assert {:ok, false} = SuiteSparse.matrix_extract(m, 1, 1)
        SuiteSparse.matrix_free(m)
      end

      test "extracts a stored fp64 value" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 3.14}], :fp64, [])
        assert {:ok, v} = SuiteSparse.matrix_extract(m, 0, 0)
        assert_in_delta v, 3.14, 0.001
        SuiteSparse.matrix_free(m)
      end

      test "extracts a stored bool value" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, true}], :bool, [])
        assert {:ok, true} = SuiteSparse.matrix_extract(m, 0, 0)
        SuiteSparse.matrix_free(m)
      end

      test "rejects out-of-bounds row" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        assert {:error, %GraphBLAS.Error{}} = SuiteSparse.matrix_extract(m, 5, 0)
        SuiteSparse.matrix_free(m)
      end
    end

    describe "matrix_dup" do
      test "creates a deep copy with same data" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 2}], :int64, [])
        {:ok, copy} = SuiteSparse.matrix_dup(m)

        {:ok, coo_orig} = SuiteSparse.matrix_to_coo(m)
        {:ok, coo_copy} = SuiteSparse.matrix_to_coo(copy)
        assert sort_coo(coo_orig) == sort_coo(coo_copy)

        SuiteSparse.matrix_free(m)
        SuiteSparse.matrix_free(copy)
      end

      test "copy is independent from original" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        {:ok, copy} = SuiteSparse.matrix_dup(m)

        {:ok, updated} = SuiteSparse.matrix_set(copy, 0, 0, 99)
        {:ok, val_copy} = SuiteSparse.matrix_extract(updated, 0, 0)
        assert val_copy == 99

        {:ok, val_orig} = SuiteSparse.matrix_extract(m, 0, 0)
        assert val_orig == 1

        SuiteSparse.matrix_free(m)
        SuiteSparse.matrix_free(copy)
        SuiteSparse.matrix_free(updated)
      end

      test "duplicates fp64 matrix" do
        {:ok, m} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1.5}], :fp64, [])
        {:ok, copy} = SuiteSparse.matrix_dup(m)

        {:ok, coo_orig} = SuiteSparse.matrix_to_coo(m)
        {:ok, coo_copy} = SuiteSparse.matrix_to_coo(copy)
        assert length(coo_orig) == length(coo_copy)

        SuiteSparse.matrix_free(m)
        SuiteSparse.matrix_free(copy)
      end
    end

    describe "vector_set" do
      test "sets an int64 value" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1}], :int64, [])
        {:ok, updated} = SuiteSparse.vector_set(v, 1, 5)
        {:ok, entries} = SuiteSparse.vector_to_entries(updated)
        assert {1, 5} in entries
        SuiteSparse.vector_free(updated)
      end

      test "sets a fp64 value" do
        {:ok, v} = SuiteSparse.vector_new(3, :fp64, [])
        {:ok, updated} = SuiteSparse.vector_set(v, 0, 2.5)
        {:ok, entries} = SuiteSparse.vector_to_entries(updated)
        assert {0, 2.5} in entries
        SuiteSparse.vector_free(updated)
      end

      test "sets a bool value" do
        {:ok, v} = SuiteSparse.vector_new(3, :bool, [])
        {:ok, updated} = SuiteSparse.vector_set(v, 1, true)
        {:ok, entries} = SuiteSparse.vector_to_entries(updated)
        assert {1, true} in entries
        SuiteSparse.vector_free(updated)
      end

      test "overwrites existing value" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1}], :int64, [])
        {:ok, updated} = SuiteSparse.vector_set(v, 0, 42)
        {:ok, entries} = SuiteSparse.vector_to_entries(updated)
        assert {0, 42} in entries
        refute {0, 1} in entries
        SuiteSparse.vector_free(updated)
      end

      test "rejects out-of-bounds index" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1}], :int64, [])
        assert {:error, %GraphBLAS.Error{}} = SuiteSparse.vector_set(v, 5, 1)
        SuiteSparse.vector_free(v)
      end
    end

    describe "vector_extract" do
      test "extracts a stored int64 value" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 42}], :int64, [])
        assert {:ok, 42} = SuiteSparse.vector_extract(v, 0)
        SuiteSparse.vector_free(v)
      end

      test "returns default for structural zero (int64)" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 42}], :int64, [])
        assert {:ok, 0} = SuiteSparse.vector_extract(v, 1)
        SuiteSparse.vector_free(v)
      end

      test "returns default for structural zero (fp64)" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1.5}], :fp64, [])
        assert {:ok, +0.0} = SuiteSparse.vector_extract(v, 1)
        SuiteSparse.vector_free(v)
      end

      test "returns default for structural zero (bool)" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, true}], :bool, [])
        assert {:ok, false} = SuiteSparse.vector_extract(v, 1)
        SuiteSparse.vector_free(v)
      end

      test "extracts a stored fp64 value" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 3.14}], :fp64, [])
        assert {:ok, val} = SuiteSparse.vector_extract(v, 0)
        assert_in_delta val, 3.14, 0.001
        SuiteSparse.vector_free(v)
      end

      test "rejects out-of-bounds index" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1}], :int64, [])
        assert {:error, %GraphBLAS.Error{}} = SuiteSparse.vector_extract(v, 5)
        SuiteSparse.vector_free(v)
      end
    end

    describe "vector_dup" do
      test "creates a deep copy with same data" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1}, {1, 2}], :int64, [])
        {:ok, copy} = SuiteSparse.vector_dup(v)

        {:ok, entries_orig} = SuiteSparse.vector_to_entries(v)
        {:ok, entries_copy} = SuiteSparse.vector_to_entries(copy)
        assert sort_entries(entries_orig) == sort_entries(entries_copy)

        SuiteSparse.vector_free(v)
        SuiteSparse.vector_free(copy)
      end

      test "copy is independent from original" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, 1}], :int64, [])
        {:ok, copy} = SuiteSparse.vector_dup(v)

        {:ok, updated} = SuiteSparse.vector_set(copy, 0, 99)
        {:ok, val_copy} = SuiteSparse.vector_extract(updated, 0)
        assert val_copy == 99

        {:ok, val_orig} = SuiteSparse.vector_extract(v, 0)
        assert val_orig == 1

        SuiteSparse.vector_free(v)
        SuiteSparse.vector_free(copy)
        SuiteSparse.vector_free(updated)
      end

      test "duplicates bool vector" do
        {:ok, v} = SuiteSparse.vector_from_entries(3, [{0, true}, {2, true}], :bool, [])
        {:ok, copy} = SuiteSparse.vector_dup(v)

        {:ok, entries_orig} = SuiteSparse.vector_to_entries(v)
        {:ok, entries_copy} = SuiteSparse.vector_to_entries(copy)
        assert sort_entries(entries_orig) == sort_entries(entries_copy)

        SuiteSparse.vector_free(v)
        SuiteSparse.vector_free(copy)
      end
    end

    describe "mask on mxm" do
      test "structural mask restricts output positions" do
        {:ok, a} =
          SuiteSparse.matrix_from_coo(
            2,
            2,
            [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}, {1, 1, 4}],
            :int64,
            []
          )

        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 1}], :int64, [])
        {:ok, mask_src} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        mask = GraphBLAS.Mask.new(mask_src)

        {:ok, c} = SuiteSparse.matrix_mxm(a, b, :plus_times, mask: mask)
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)

        for {r, cv, _v} <- coo do
          assert {r, cv} == {0, 0}
        end

        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(mask_src)
        SuiteSparse.matrix_free(c)
      end

      test "complement mask restricts output to non-mask positions" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 1}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 1}], :int64, [])
        {:ok, mask_src} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        mask = GraphBLAS.Mask.complement(mask_src)

        {:ok, c} = SuiteSparse.matrix_mxm(a, b, :plus_times, mask: mask)
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)

        for {r, cv, _v} <- coo do
          refute {r, cv} == {0, 0}
        end

        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(mask_src)
        SuiteSparse.matrix_free(c)
      end
    end

    describe "descriptor on mxm" do
      test "descriptor with inp0_transpose" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 1}, {1, 2, 2}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 3}, {1, 2, 4}], :int64, [])

        desc = GraphBLAS.Descriptor.new(inp0_transpose: :transpose)
        {:ok, c} = SuiteSparse.matrix_mxm(a, b, :plus_times, descriptor: desc)
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)

        assert coo != []

        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end

      test "descriptor with inp1_transpose" do
        {:ok, a} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 1}], :int64, [])
        {:ok, b} = SuiteSparse.matrix_from_coo(2, 3, [{0, 1, 1}], :int64, [])

        desc = GraphBLAS.Descriptor.new(inp1_transpose: :transpose)
        {:ok, c} = SuiteSparse.matrix_mxm(a, b, :plus_times, descriptor: desc)
        {:ok, coo} = SuiteSparse.matrix_to_coo(c)

        assert is_list(coo)

        SuiteSparse.matrix_free(a)
        SuiteSparse.matrix_free(b)
        SuiteSparse.matrix_free(c)
      end
    end

    defp sort_coo(entries) do
      Enum.sort_by(entries, fn {r, c, _v} -> {r, c} end)
    end

    defp sort_entries(entries) do
      Enum.sort_by(entries, fn {i, _v} -> i end)
    end
  end
else
  defmodule GraphBLAS.SuiteSparseBackendTest do
    use ExUnit.Case
    @moduletag :skip
    @tag :native_backend
    test "skipped: native backend not compiled (set EX_GRAPHBLAS_COMPILE_NATIVE=1)" do
      :ok
    end
  end
end
