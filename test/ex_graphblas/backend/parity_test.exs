if System.get_env("EX_GRAPHBLAS_COMPILE_NATIVE") in ["1", "true"] do
  defmodule GraphBLAS.Backend.ParityTest do
    use ExUnit.Case, async: false

    @moduletag :native_backend

    alias GraphBLAS.Backend.Elixir, as: RefBackend
    alias GraphBLAS.Backend.SuiteSparse

    # Valid semiring/type pairs and test data for mxm/mxv/vxm
    # Each entry: {semiring, type, matrix_a_entries, matrix_b_entries, expected_nonzero_count}
    # Matrix A is 2x3, Matrix B is 3x2 for mxm
    # Matrix is 2x3, Vector is 3 for mxv
    # Vector is 2, Matrix is 2x3 for vxm

    @semiring_mxm_cases [
      {:plus_times, :int64, [{0, 1, 2}, {1, 2, 3}], [{1, 0, 1}, {2, 1, 4}]},
      {:plus_times_fp64, :fp64, [{0, 1, 1.5}, {1, 2, 2.5}], [{1, 0, 2.0}, {2, 1, 3.0}]},
      {:plus_min, :int64, [{0, 1, 5}, {1, 2, 3}], [{1, 0, 2}, {2, 1, 4}]},
      {:plus_min_fp64, :fp64, [{0, 1, 5.0}, {1, 2, 3.0}], [{1, 0, 2.0}, {2, 1, 4.0}]},
      {:max_plus, :int64, [{0, 1, 2}, {1, 2, 3}], [{1, 0, 1}, {2, 1, 4}]},
      {:max_plus_fp64, :fp64, [{0, 1, 2.0}, {1, 2, 3.0}], [{1, 0, 1.0}, {2, 1, 4.0}]},
      {:max_min, :int64, [{0, 1, 5}, {1, 2, 3}], [{1, 0, 2}, {2, 1, 4}]},
      {:max_min_fp64, :fp64, [{0, 1, 5.0}, {1, 2, 3.0}], [{1, 0, 2.0}, {2, 1, 4.0}]},
      {:lor_land, :bool, [{0, 1, true}, {1, 2, true}], [{1, 0, true}, {2, 1, true}]},
      {:land_lor, :bool, [{0, 1, true}, {1, 2, false}], [{1, 0, true}, {2, 1, true}]}
    ]

    # Monoid/type pairs for ewise operations
    # {monoid, type, entries_a, entries_b}
    @monoid_ewise_cases [
      {:plus, :int64, [{0, 0, 1}, {1, 1, 2}], [{0, 0, 3}, {1, 1, 4}]},
      {:plus_fp64, :fp64, [{0, 0, 1.5}, {1, 1, 2.5}], [{0, 0, 3.5}, {1, 1, 4.5}]},
      {:times, :int64, [{0, 0, 2}, {1, 1, 3}], [{0, 0, 4}, {1, 1, 5}]},
      {:times_fp64, :fp64, [{0, 0, 2.0}, {1, 1, 3.0}], [{0, 0, 4.0}, {1, 1, 5.0}]},
      {:min, :int64, [{0, 0, 5}, {1, 1, 2}], [{0, 0, 3}, {1, 1, 7}]},
      {:min_fp64, :fp64, [{0, 0, 5.0}, {1, 1, 2.0}], [{0, 0, 3.0}, {1, 1, 7.0}]},
      {:max, :int64, [{0, 0, 5}, {1, 1, 2}], [{0, 0, 3}, {1, 1, 7}]},
      {:max_fp64, :fp64, [{0, 0, 5.0}, {1, 1, 2.0}], [{0, 0, 3.0}, {1, 1, 7.0}]},
      {:land, :bool, [{0, 0, true}, {1, 1, true}], [{0, 0, true}, {1, 1, false}]},
      {:lor, :bool, [{0, 0, true}, {1, 1, false}], [{0, 0, true}, {1, 1, true}]},
      {:lxor, :bool, [{0, 0, true}, {1, 1, true}], [{0, 0, true}, {1, 1, false}]}
    ]

    describe "matrix_mxm parity — all semirings" do
      for {semiring, type, entries_a, entries_b} <- @semiring_mxm_cases do
        test "#{semiring} / #{type}" do
          {semiring, type, entries_a, entries_b} =
            unquote(Macro.escape({semiring, type, entries_a, entries_b}))

          {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, entries_a, type, [])
          {:ok, ref_b} = RefBackend.matrix_from_coo(3, 2, entries_b, type, [])
          {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, entries_a, type, [])
          {:ok, ss_b} = SuiteSparse.matrix_from_coo(3, 2, entries_b, type, [])

          {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, semiring, [])
          {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, semiring, [])

          {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
          {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

          if type == :fp64 do
            assert_coo_approx_equal(ref_coo, ss_coo)
          else
            assert sort_coo(ref_coo) == sort_coo(ss_coo)
          end

          SuiteSparse.matrix_free(ss_a)
          SuiteSparse.matrix_free(ss_b)
          SuiteSparse.matrix_free(ss_c)
        end
      end
    end

    describe "matrix_mxv parity — all semirings" do
      for {semiring, type, entries_m, _entries_b} <- @semiring_mxm_cases do
        test "#{semiring} / #{type}" do
          {semiring, type, entries_m, _} = unquote(Macro.escape({semiring, type, entries_m, nil}))

          vector_entries =
            case type do
              :int64 -> [{1, 10}, {2, 5}]
              :fp64 -> [{1, 10.0}, {2, 5.0}]
              :bool -> [{1, true}, {2, true}]
            end

          {:ok, ref_m} = RefBackend.matrix_from_coo(2, 3, entries_m, type, [])
          {:ok, ref_v} = RefBackend.vector_from_entries(3, vector_entries, type, [])
          {:ok, ss_m} = SuiteSparse.matrix_from_coo(2, 3, entries_m, type, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(3, vector_entries, type, [])

          {:ok, ref_r} = RefBackend.matrix_mxv(ref_m, ref_v, semiring, [])
          {:ok, ss_r} = SuiteSparse.matrix_mxv(ss_m, ss_v, semiring, [])

          {:ok, ref_e} = RefBackend.vector_to_entries(ref_r)
          {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_r)

          if type == :fp64 do
            assert_entries_approx_equal(ref_e, ss_e)
          else
            assert sort_entries(ref_e) == sort_entries(ss_e)
          end

          SuiteSparse.matrix_free(ss_m)
          SuiteSparse.vector_free(ss_v)
          SuiteSparse.vector_free(ss_r)
        end
      end
    end

    describe "vector_vxm parity — all semirings" do
      for {semiring, type, entries_a, _} <- @semiring_mxm_cases do
        test "#{semiring} / #{type}" do
          {semiring, type, entries_a, _} = unquote(Macro.escape({semiring, type, entries_a, nil}))

          vector_entries =
            case type do
              :int64 -> [{0, 1}, {2, 2}]
              :fp64 -> [{0, 1.0}, {2, 2.0}]
              :bool -> [{0, true}, {2, true}]
            end

          matrix_entries =
            case type do
              :int64 -> [{0, 0, 3}, {2, 1, 4}]
              :fp64 -> [{0, 0, 3.0}, {2, 1, 4.0}]
              :bool -> [{0, 0, true}, {2, 1, true}]
            end

          {:ok, ref_v} = RefBackend.vector_from_entries(3, vector_entries, type, [])
          {:ok, ref_m} = RefBackend.matrix_from_coo(3, 2, matrix_entries, type, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(3, vector_entries, type, [])
          {:ok, ss_m} = SuiteSparse.matrix_from_coo(3, 2, matrix_entries, type, [])

          {:ok, ref_r} = RefBackend.vector_vxm(ref_v, ref_m, semiring, [])
          {:ok, ss_r} = SuiteSparse.vector_vxm(ss_v, ss_m, semiring, [])

          {:ok, ref_e} = RefBackend.vector_to_entries(ref_r)
          {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_r)

          if type == :fp64 do
            assert_entries_approx_equal(ref_e, ss_e)
          else
            assert sort_entries(ref_e) == sort_entries(ss_e)
          end

          SuiteSparse.vector_free(ss_v)
          SuiteSparse.matrix_free(ss_m)
          SuiteSparse.vector_free(ss_r)
        end
      end
    end

    describe "matrix_ewise_add parity — all monoids" do
      for {monoid, type, entries_a, entries_b} <- @monoid_ewise_cases do
        test "#{monoid} / #{type}" do
          {monoid, type, entries_a, entries_b} =
            unquote(Macro.escape({monoid, type, entries_a, entries_b}))

          {:ok, ref_a} = RefBackend.matrix_from_coo(2, 2, entries_a, type, [])
          {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, entries_b, type, [])
          {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 2, entries_a, type, [])
          {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, entries_b, type, [])

          {:ok, ref_c} = RefBackend.matrix_ewise_add(ref_a, ref_b, monoid, [])
          {:ok, ss_c} = SuiteSparse.matrix_ewise_add(ss_a, ss_b, monoid, [])

          {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
          {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

          if type == :fp64 do
            assert_coo_approx_equal(ref_coo, ss_coo)
          else
            assert sort_coo(ref_coo) == sort_coo(ss_coo)
          end

          SuiteSparse.matrix_free(ss_a)
          SuiteSparse.matrix_free(ss_b)
          SuiteSparse.matrix_free(ss_c)
        end
      end
    end

    describe "matrix_ewise_mult parity — all monoids" do
      for {monoid, type, entries_a, entries_b} <- @monoid_ewise_cases do
        test "#{monoid} / #{type}" do
          {monoid, type, entries_a, entries_b} =
            unquote(Macro.escape({monoid, type, entries_a, entries_b}))

          {:ok, ref_a} = RefBackend.matrix_from_coo(2, 2, entries_a, type, [])
          {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, entries_b, type, [])
          {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 2, entries_a, type, [])
          {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, entries_b, type, [])

          {:ok, ref_c} = RefBackend.matrix_ewise_mult(ref_a, ref_b, monoid, [])
          {:ok, ss_c} = SuiteSparse.matrix_ewise_mult(ss_a, ss_b, monoid, [])

          {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
          {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

          if type == :fp64 do
            assert_coo_approx_equal(ref_coo, ss_coo)
          else
            assert sort_coo(ref_coo) == sort_coo(ss_coo)
          end

          SuiteSparse.matrix_free(ss_a)
          SuiteSparse.matrix_free(ss_b)
          SuiteSparse.matrix_free(ss_c)
        end
      end
    end

    describe "matrix_reduce parity — all monoids" do
      for {monoid, type, entries_a, _entries_b} <- @monoid_ewise_cases do
        test "#{monoid} / #{type}" do
          {monoid, type, entries_a, _} = unquote(Macro.escape({monoid, type, entries_a, nil}))

          {:ok, ref} = RefBackend.matrix_from_coo(2, 2, entries_a, type, [])
          {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, entries_a, type, [])

          {:ok, ref_v} = RefBackend.matrix_reduce(ref, monoid, [])
          {:ok, ss_v} = SuiteSparse.matrix_reduce(ss, monoid, [])

          {:ok, ref_e} = RefBackend.vector_to_entries(ref_v)
          {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_v)

          if type == :fp64 do
            assert_entries_approx_equal(ref_e, ss_e)
          else
            assert sort_entries(ref_e) == sort_entries(ss_e)
          end

          SuiteSparse.matrix_free(ss)
          SuiteSparse.vector_free(ss_v)
        end
      end
    end

    describe "vector_ewise_add parity — all monoids" do
      for {monoid, type, entries_a, entries_b} <- @monoid_ewise_cases do
        test "#{monoid} / #{type}" do
          {monoid, type, entries_a, entries_b} =
            unquote(Macro.escape({monoid, type, entries_a, entries_b}))

          vec_a = Enum.map(entries_a, fn {r, _c, v} -> {r, v} end)
          vec_b = Enum.map(entries_b, fn {r, _c, v} -> {r, v} end)

          {:ok, ref_a} = RefBackend.vector_from_entries(2, vec_a, type, [])
          {:ok, ref_b} = RefBackend.vector_from_entries(2, vec_b, type, [])
          {:ok, ss_a} = SuiteSparse.vector_from_entries(2, vec_a, type, [])
          {:ok, ss_b} = SuiteSparse.vector_from_entries(2, vec_b, type, [])

          {:ok, ref_c} = RefBackend.vector_ewise_add(ref_a, ref_b, monoid, [])
          {:ok, ss_c} = SuiteSparse.vector_ewise_add(ss_a, ss_b, monoid, [])

          {:ok, ref_e} = RefBackend.vector_to_entries(ref_c)
          {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_c)

          if type == :fp64 do
            assert_entries_approx_equal(ref_e, ss_e)
          else
            assert sort_entries(ref_e) == sort_entries(ss_e)
          end

          SuiteSparse.vector_free(ss_a)
          SuiteSparse.vector_free(ss_b)
          SuiteSparse.vector_free(ss_c)
        end
      end
    end

    describe "vector_ewise_mult parity — all monoids" do
      for {monoid, type, entries_a, entries_b} <- @monoid_ewise_cases do
        test "#{monoid} / #{type}" do
          {monoid, type, entries_a, entries_b} =
            unquote(Macro.escape({monoid, type, entries_a, entries_b}))

          vec_a = Enum.map(entries_a, fn {r, _c, v} -> {r, v} end)
          vec_b = Enum.map(entries_b, fn {r, _c, v} -> {r, v} end)

          {:ok, ref_a} = RefBackend.vector_from_entries(2, vec_a, type, [])
          {:ok, ref_b} = RefBackend.vector_from_entries(2, vec_b, type, [])
          {:ok, ss_a} = SuiteSparse.vector_from_entries(2, vec_a, type, [])
          {:ok, ss_b} = SuiteSparse.vector_from_entries(2, vec_b, type, [])

          {:ok, ref_c} = RefBackend.vector_ewise_mult(ref_a, ref_b, monoid, [])
          {:ok, ss_c} = SuiteSparse.vector_ewise_mult(ss_a, ss_b, monoid, [])

          {:ok, ref_e} = RefBackend.vector_to_entries(ref_c)
          {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_c)

          if type == :fp64 do
            assert_entries_approx_equal(ref_e, ss_e)
          else
            assert sort_entries(ref_e) == sort_entries(ss_e)
          end

          SuiteSparse.vector_free(ss_a)
          SuiteSparse.vector_free(ss_b)
          SuiteSparse.vector_free(ss_c)
        end
      end
    end

    describe "vector_reduce parity — all monoids" do
      for {monoid, type, entries_a, _} <- @monoid_ewise_cases do
        test "#{monoid} / #{type}" do
          {monoid, type, entries_a, _} = unquote(Macro.escape({monoid, type, entries_a, nil}))

          vec_entries = Enum.map(entries_a, fn {r, _c, v} -> {r, v} end)

          {:ok, ref} = RefBackend.vector_from_entries(2, vec_entries, type, [])
          {:ok, ss} = SuiteSparse.vector_from_entries(2, vec_entries, type, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref, monoid, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss, monoid, [])

          if type == :fp64 do
            assert_in_delta ref_s.value, ss_s.value, 0.001
          else
            assert ref_s.value == ss_s.value
          end

          SuiteSparse.vector_free(ss)
        end
      end
    end

    # --- Edge case tests ---

    describe "edge cases" do
      test "empty matrix produces zero nvals" do
        {:ok, ref} = RefBackend.matrix_from_coo(3, 3, [], :int64, [])
        {:ok, ss} = SuiteSparse.matrix_from_coo(3, 3, [], :int64, [])

        {:ok, ref_nvals} = RefBackend.matrix_nvals(ref)
        {:ok, ss_nvals} = SuiteSparse.matrix_nvals(ss)

        assert ref_nvals == 0
        assert ss_nvals == 0
        SuiteSparse.matrix_free(ss)
      end

      test "empty matrix to_coo returns empty list" do
        {:ok, ref} = RefBackend.matrix_from_coo(3, 3, [], :int64, [])
        {:ok, ss} = SuiteSparse.matrix_from_coo(3, 3, [], :int64, [])

        {:ok, ref_coo} = RefBackend.matrix_to_coo(ref)
        {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss)

        assert ref_coo == []
        assert ss_coo == []
        SuiteSparse.matrix_free(ss)
      end

      test "empty vector reduces to monoid identity" do
        for {monoid, type, identity} <- [
              {:plus, :int64, 0},
              {:plus_fp64, :fp64, 0.0},
              {:times, :int64, 1},
              {:times_fp64, :fp64, 1.0},
              {:lor, :bool, false},
              {:land, :bool, true}
            ] do
          {:ok, ref} = RefBackend.vector_from_entries(3, [], type, [])
          {:ok, ss} = SuiteSparse.vector_from_entries(3, [], type, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref, monoid, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss, monoid, [])

          if type == :fp64 do
            assert_in_delta identity, ss_s.value, 0.001
            assert_in_delta identity, ref_s.value, 0.001
          else
            assert identity == ref_s.value
            assert identity == ss_s.value
          end

          SuiteSparse.vector_free(ss)
        end
      end

      test "single element matrix mxm with identity" do
        entries = [{0, 0, 1}]
        {:ok, ref_i} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
        {:ok, ss_i} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])

        {:ok, ref_c} = RefBackend.matrix_mxm(ref_i, ref_i, :plus_times, [])
        {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_i, ss_i, :plus_times, [])

        {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
        {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

        assert sort_coo(ref_coo) == sort_coo(ss_coo)
        SuiteSparse.matrix_free(ss_i)
        SuiteSparse.matrix_free(ss_c)
      end

      test "duplicate entries are combined with plus monoid (default)" do
        entries = [{0, 0, 3}, {0, 0, 5}]
        {:ok, ref} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
        {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])

        {:ok, ref_coo} = RefBackend.matrix_to_coo(ref)
        {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss)

        assert {0, 0, 8} in sort_coo(ref_coo)
        assert {0, 0, 8} in sort_coo(ss_coo)
        SuiteSparse.matrix_free(ss)
      end

      test "duplicate entries with custom combine monoid (RefBackend)" do
        entries = [{0, 0, 3}, {0, 0, 5}]

        {:ok, ref_times} =
          RefBackend.matrix_from_coo(2, 2, entries, :int64, combine_monoid: :times)

        {:ok, times_coo} = RefBackend.matrix_to_coo(ref_times)
        assert {0, 0, 15} in sort_coo(times_coo)

        {:ok, ref_max} = RefBackend.matrix_from_coo(2, 2, entries, :int64, combine_monoid: :max)
        {:ok, max_coo} = RefBackend.matrix_to_coo(ref_max)
        assert {0, 0, 5} in sort_coo(max_coo)

        {:ok, ref_min} = RefBackend.matrix_from_coo(2, 2, entries, :int64, combine_monoid: :min)
        {:ok, min_coo} = RefBackend.matrix_to_coo(ref_min)
        assert {0, 0, 3} in sort_coo(min_coo)
      end

      test "dimension mismatch returns error" do
        {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, [{0, 0, 1}], :int64, [])
        {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
        {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, [{0, 0, 1}], :int64, [])
        {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])

        ref_result = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times, [])

        # SuiteSparse may crash or return error for dimension mismatch
        # Both backends should reject this
        assert match?({:error, _}, ref_result)

        SuiteSparse.matrix_free(ss_a)
        SuiteSparse.matrix_free(ss_b)
      end

      test "unsupported type returns error" do
        result = SuiteSparse.matrix_new(3, 3, :int32, [])

        assert match?({:error, _}, result)
      end

      test "fp64 mxm with larger matrix" do
        entries_a = [{0, 0, 1.0}, {0, 1, 2.0}, {1, 1, 3.0}]
        entries_b = [{0, 0, 1.0}, {1, 0, 2.0}, {1, 1, 4.0}]

        {:ok, ref_a} = RefBackend.matrix_from_coo(2, 2, entries_a, :fp64, [])
        {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, entries_b, :fp64, [])
        {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 2, entries_a, :fp64, [])
        {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, entries_b, :fp64, [])

        {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times_fp64, [])
        {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :plus_times_fp64, [])

        {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
        {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

        assert_coo_approx_equal(ref_coo, ss_coo)
        SuiteSparse.matrix_free(ss_a)
        SuiteSparse.matrix_free(ss_b)
        SuiteSparse.matrix_free(ss_c)
      end
    end

    # --- Helper functions ---

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

    defp assert_entries_approx_equal(ref, ss) do
      ref_sorted = sort_entries(ref)
      ss_sorted = sort_entries(ss)

      assert length(ref_sorted) == length(ss_sorted)

      Enum.zip_with(ref_sorted, ss_sorted, fn {i1, v1}, {i2, v2} ->
        assert i1 == i2
        assert_in_delta v1, v2, 0.001
      end)
    end

    # --- Phase 5: set/extract/dup parity ---

    describe "matrix_set / matrix_extract parity" do
      test "set and extract int64 values match between backends" do
        {:ok, ref} = RefBackend.matrix_from_coo(3, 3, [{0, 0, 1}, {1, 1, 2}], :int64, [])
        {:ok, ss} = SuiteSparse.matrix_from_coo(3, 3, [{0, 0, 1}, {1, 1, 2}], :int64, [])

        {:ok, ref_set} = RefBackend.matrix_set(ref, 2, 2, 42)
        {:ok, ss_set} = SuiteSparse.matrix_set(ss, 2, 2, 42)

        {:ok, ref_val} = RefBackend.matrix_extract(ref_set, 2, 2)
        {:ok, ss_val} = SuiteSparse.matrix_extract(ss_set, 2, 2)
        assert ref_val == ss_val

        {:ok, ref_default} = RefBackend.matrix_extract(ref_set, 0, 1)
        {:ok, ss_default} = SuiteSparse.matrix_extract(ss_set, 0, 1)
        assert ref_default == ss_default

        SuiteSparse.matrix_free(ss)
        SuiteSparse.matrix_free(ss_set)
      end

      test "set and extract fp64 values match between backends" do
        {:ok, ref} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1.5}], :fp64, [])
        {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, [{0, 0, 1.5}], :fp64, [])

        {:ok, ref_set} = RefBackend.matrix_set(ref, 1, 1, 3.14)
        {:ok, ss_set} = SuiteSparse.matrix_set(ss, 1, 1, 3.14)

        {:ok, ref_val} = RefBackend.matrix_extract(ref_set, 1, 1)
        {:ok, ss_val} = SuiteSparse.matrix_extract(ss_set, 1, 1)
        assert_in_delta ref_val, ss_val, 0.001

        SuiteSparse.matrix_free(ss)
        SuiteSparse.matrix_free(ss_set)
      end

      test "set and extract bool values match between backends" do
        {:ok, ref} = RefBackend.matrix_from_coo(2, 2, [], :bool, [])
        {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, [], :bool, [])

        {:ok, ref_set} = RefBackend.matrix_set(ref, 0, 1, true)
        {:ok, ss_set} = SuiteSparse.matrix_set(ss, 0, 1, true)

        {:ok, ref_val} = RefBackend.matrix_extract(ref_set, 0, 1)
        {:ok, ss_val} = SuiteSparse.matrix_extract(ss_set, 0, 1)
        assert ref_val == ss_val

        {:ok, ref_default} = RefBackend.matrix_extract(ref_set, 1, 0)
        {:ok, ss_default} = SuiteSparse.matrix_extract(ss_set, 1, 0)
        assert ref_default == ss_default

        SuiteSparse.matrix_free(ss)
        SuiteSparse.matrix_free(ss_set)
      end
    end

    describe "matrix_dup parity" do
      test "dup produces same entries as original" do
        entries = [{0, 0, 5}, {0, 1, 3}, {1, 1, 7}]
        {:ok, ref} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
        {:ok, ss} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])

        {:ok, ref_dup} = RefBackend.matrix_dup(ref)
        {:ok, ss_dup} = SuiteSparse.matrix_dup(ss)

        {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_dup)
        {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_dup)

        assert sort_coo(ref_coo) == sort_coo(ss_coo)

        SuiteSparse.matrix_free(ss)
        SuiteSparse.matrix_free(ss_dup)
      end
    end

    describe "vector_set / vector_extract parity" do
      test "set and extract int64 values match between backends" do
        {:ok, ref} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
        {:ok, ss} = SuiteSparse.vector_from_entries(3, [{0, 1}], :int64, [])

        {:ok, ref_set} = RefBackend.vector_set(ref, 2, 42)
        {:ok, ss_set} = SuiteSparse.vector_set(ss, 2, 42)

        {:ok, ref_val} = RefBackend.vector_extract(ref_set, 2)
        {:ok, ss_val} = SuiteSparse.vector_extract(ss_set, 2)
        assert ref_val == ss_val

        {:ok, ref_default} = RefBackend.vector_extract(ref_set, 1)
        {:ok, ss_default} = SuiteSparse.vector_extract(ss_set, 1)
        assert ref_default == ss_default

        SuiteSparse.vector_free(ss)
        SuiteSparse.vector_free(ss_set)
      end

      test "set and extract fp64 values match between backends" do
        {:ok, ref} = RefBackend.vector_from_entries(3, [{0, 1.5}], :fp64, [])
        {:ok, ss} = SuiteSparse.vector_from_entries(3, [{0, 1.5}], :fp64, [])

        {:ok, ref_set} = RefBackend.vector_set(ref, 1, 2.5)
        {:ok, ss_set} = SuiteSparse.vector_set(ss, 1, 2.5)

        {:ok, ref_val} = RefBackend.vector_extract(ref_set, 1)
        {:ok, ss_val} = SuiteSparse.vector_extract(ss_set, 1)
        assert_in_delta ref_val, ss_val, 0.001

        SuiteSparse.vector_free(ss)
        SuiteSparse.vector_free(ss_set)
      end

      test "set and extract bool values match between backends" do
        {:ok, ref} = RefBackend.vector_from_entries(3, [], :bool, [])
        {:ok, ss} = SuiteSparse.vector_from_entries(3, [], :bool, [])

        {:ok, ref_set} = RefBackend.vector_set(ref, 0, true)
        {:ok, ss_set} = SuiteSparse.vector_set(ss, 0, true)

        {:ok, ref_val} = RefBackend.vector_extract(ref_set, 0)
        {:ok, ss_val} = SuiteSparse.vector_extract(ss_set, 0)
        assert ref_val == ss_val

        SuiteSparse.vector_free(ss)
        SuiteSparse.vector_free(ss_set)
      end
    end

    describe "vector_dup parity" do
      test "dup produces same entries as original" do
        entries = [{0, 5}, {2, 3}]
        {:ok, ref} = RefBackend.vector_from_entries(4, entries, :int64, [])
        {:ok, ss} = SuiteSparse.vector_from_entries(4, entries, :int64, [])

        {:ok, ref_dup} = RefBackend.vector_dup(ref)
        {:ok, ss_dup} = SuiteSparse.vector_dup(ss)

        {:ok, ref_e} = RefBackend.vector_to_entries(ref_dup)
        {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_dup)

        assert sort_entries(ref_e) == sort_entries(ss_e)

        SuiteSparse.vector_free(ss)
        SuiteSparse.vector_free(ss_dup)
      end
    end

    # --- Phase 5: mask/descriptor parity ---

    describe "mask parity on matrix_mxm" do
      test "structural mask produces same results on both backends" do
        entries_a = [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}, {1, 1, 4}]
        entries_b = [{0, 0, 1}, {1, 1, 1}]
        mask_entries = [{0, 0, 1}]

        {:ok, ref_a} = RefBackend.matrix_from_coo(2, 2, entries_a, :int64, [])
        {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, entries_b, :int64, [])
        {:ok, ref_mask_src} = RefBackend.matrix_from_coo(2, 2, mask_entries, :int64, [])
        ref_mask = GraphBLAS.Mask.new(ref_mask_src)

        {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 2, entries_a, :int64, [])
        {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, entries_b, :int64, [])
        {:ok, ss_mask_src} = SuiteSparse.matrix_from_coo(2, 2, mask_entries, :int64, [])
        ss_mask = GraphBLAS.Mask.new(ss_mask_src)

        {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times, mask: ref_mask)
        {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :plus_times, mask: ss_mask)

        {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
        {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

        assert sort_coo(ref_coo) == sort_coo(ss_coo)

        SuiteSparse.matrix_free(ss_a)
        SuiteSparse.matrix_free(ss_b)
        SuiteSparse.matrix_free(ss_mask_src)
        SuiteSparse.matrix_free(ss_c)
      end

      test "complement mask produces same results on both backends" do
        entries_a = [{0, 0, 1}, {1, 1, 1}]
        entries_b = [{0, 0, 1}, {1, 1, 1}]
        mask_entries = [{0, 0, 1}]

        {:ok, ref_a} = RefBackend.matrix_from_coo(2, 2, entries_a, :int64, [])
        {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, entries_b, :int64, [])
        {:ok, ref_mask_src} = RefBackend.matrix_from_coo(2, 2, mask_entries, :int64, [])
        ref_mask = GraphBLAS.Mask.complement(ref_mask_src)

        {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 2, entries_a, :int64, [])
        {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, entries_b, :int64, [])
        {:ok, ss_mask_src} = SuiteSparse.matrix_from_coo(2, 2, mask_entries, :int64, [])
        ss_mask = GraphBLAS.Mask.complement(ss_mask_src)

        {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times, mask: ref_mask)
        {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :plus_times, mask: ss_mask)

        {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
        {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

        assert sort_coo(ref_coo) == sort_coo(ss_coo)

        SuiteSparse.matrix_free(ss_a)
        SuiteSparse.matrix_free(ss_b)
        SuiteSparse.matrix_free(ss_mask_src)
        SuiteSparse.matrix_free(ss_c)
      end
    end

    describe "mask parity on vector_ewise_add" do
      test "structural vector mask produces same results on both backends" do
        {:ok, ref_a} = RefBackend.vector_from_entries(3, [{0, 1}, {1, 2}, {2, 3}], :int64, [])
        {:ok, ref_b} = RefBackend.vector_from_entries(3, [{0, 10}, {1, 20}], :int64, [])
        {:ok, ref_mask_src} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
        ref_mask = GraphBLAS.Mask.new(ref_mask_src)

        {:ok, ss_a} = SuiteSparse.vector_from_entries(3, [{0, 1}, {1, 2}, {2, 3}], :int64, [])
        {:ok, ss_b} = SuiteSparse.vector_from_entries(3, [{0, 10}, {1, 20}], :int64, [])
        {:ok, ss_mask_src} = SuiteSparse.vector_from_entries(3, [{0, 1}], :int64, [])
        ss_mask = GraphBLAS.Mask.new(ss_mask_src)

        {:ok, ref_c} = RefBackend.vector_ewise_add(ref_a, ref_b, :plus, mask: ref_mask)
        {:ok, ss_c} = SuiteSparse.vector_ewise_add(ss_a, ss_b, :plus, mask: ss_mask)

        {:ok, ref_e} = RefBackend.vector_to_entries(ref_c)
        {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_c)

        assert sort_entries(ref_e) == sort_entries(ss_e)

        SuiteSparse.vector_free(ss_a)
        SuiteSparse.vector_free(ss_b)
        SuiteSparse.vector_free(ss_mask_src)
        SuiteSparse.vector_free(ss_c)
      end
    end

    describe "descriptor parity on matrix_mxm — inp0_transpose" do
      test "inp0_transpose produces same results on both backends" do
        entries_a = [{0, 1, 1}, {1, 2, 2}]
        entries_b = [{0, 1, 3}, {1, 2, 4}]

        desc = GraphBLAS.Descriptor.new(inp0_transpose: :transpose)

        {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, entries_a, :int64, [])
        {:ok, ref_b} = RefBackend.matrix_from_coo(2, 3, entries_b, :int64, [])
        {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, entries_a, :int64, [])
        {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 3, entries_b, :int64, [])

        {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times, descriptor: desc)
        {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :plus_times, descriptor: desc)

        {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
        {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

        assert sort_coo(ref_coo) == sort_coo(ss_coo)

        SuiteSparse.matrix_free(ss_a)
        SuiteSparse.matrix_free(ss_b)
        SuiteSparse.matrix_free(ss_c)
      end
    end
  end
end
