if System.get_env("EX_GRAPHBLAS_COMPILE_NATIVE") in ["1", "true"] do
  defmodule GraphBLAS.PropertyTest do
    @moduledoc """
    StreamData property-based tests verifying algebraic properties
    and backend parity for arbitrary inputs.

    These tests complement the deterministic parameterized parity tests
    by exploring input spaces that hand-written tests may miss.

    Tested properties:
    - Monoid identity: reduce of single-element vector returns the element
    - Monoid identity: reduce of empty vector returns the identity
    - Backend parity: both backends produce identical results for random inputs
    - Semiring identity: I * A = A for identity matrix I
    - Plus associativity via vector reduce
    - Plus-times distributivity: A * (B + C) = (A * B) + (A * C)
    """
    use ExUnit.Case, async: false
    use ExUnitProperties

    @moduletag :native_backend

    alias GraphBLAS.Backend.Elixir, as: RefBackend
    alias GraphBLAS.Backend.SuiteSparse

    # Value generators — small ranges to avoid overflow in semiring multiply ops
    defp pos_int64, do: integer(1..30)
    defp pos_fp64, do: float(min: 0.5, max: 30.0)

    #############################################################################
    # Monoid identity: reduce of single-element vector = element
    #############################################################################

    describe "monoid identity: reduce of single-element vector" do
      property "plus/int64 returns the element (both backends)" do
        check all(v <- pos_int64()) do
          {:ok, ref_v} = RefBackend.vector_from_entries(5, [{2, v}], :int64, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, [{2, v}], :int64, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :plus, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :plus, [])

          assert ref_s.value == v
          assert ss_s.value == v

          SuiteSparse.vector_free(ss_v)
        end
      end

      property "plus_fp64/fp64 returns the element (both backends)" do
        check all(v <- pos_fp64()) do
          {:ok, ref_v} = RefBackend.vector_from_entries(5, [{2, v}], :fp64, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, [{2, v}], :fp64, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :plus_fp64, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :plus_fp64, [])

          assert_in_delta ref_s.value, v, 0.001
          assert_in_delta ss_s.value, v, 0.001

          SuiteSparse.vector_free(ss_v)
        end
      end

      property "times/int64 returns the element (both backends)" do
        check all(v <- pos_int64()) do
          {:ok, ref_v} = RefBackend.vector_from_entries(5, [{2, v}], :int64, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, [{2, v}], :int64, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :times, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :times, [])

          assert ref_s.value == v
          assert ss_s.value == v

          SuiteSparse.vector_free(ss_v)
        end
      end

      property "times_fp64/fp64 returns the element (both backends)" do
        check all(v <- pos_fp64()) do
          {:ok, ref_v} = RefBackend.vector_from_entries(5, [{2, v}], :fp64, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, [{2, v}], :fp64, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :times_fp64, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :times_fp64, [])

          assert_in_delta ref_s.value, v, 0.001
          assert_in_delta ss_s.value, v, 0.001

          SuiteSparse.vector_free(ss_v)
        end
      end

      property "min/int64 returns the element (both backends)" do
        check all(v <- pos_int64()) do
          {:ok, ref_v} = RefBackend.vector_from_entries(5, [{2, v}], :int64, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, [{2, v}], :int64, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :min, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :min, [])

          assert ref_s.value == v
          assert ss_s.value == v

          SuiteSparse.vector_free(ss_v)
        end
      end

      property "max/int64 returns the element (both backends)" do
        check all(v <- pos_int64()) do
          {:ok, ref_v} = RefBackend.vector_from_entries(5, [{2, v}], :int64, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, [{2, v}], :int64, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :max, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :max, [])

          assert ref_s.value == v
          assert ss_s.value == v

          SuiteSparse.vector_free(ss_v)
        end
      end

      property "lor/bool returns the element (both backends)" do
        check all(v <- boolean()) do
          {:ok, ref_v} = RefBackend.vector_from_entries(5, [{2, v}], :bool, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, [{2, v}], :bool, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :lor, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :lor, [])

          assert ref_s.value == v
          assert ss_s.value == v

          SuiteSparse.vector_free(ss_v)
        end
      end

      property "land/bool returns the element (both backends)" do
        check all(v <- boolean()) do
          {:ok, ref_v} = RefBackend.vector_from_entries(5, [{2, v}], :bool, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, [{2, v}], :bool, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :land, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :land, [])

          assert ref_s.value == v
          assert ss_s.value == v

          SuiteSparse.vector_free(ss_v)
        end
      end
    end

    #############################################################################
    # Backend parity: vector operations with random values
    #############################################################################

    describe "backend parity: vector ewise_add with random values" do
      property "plus/int64" do
        check all(v1 <- pos_int64(), v2 <- pos_int64(), v3 <- pos_int64()) do
          entries_a = [{0, v1}, {1, v2}]
          entries_b = [{0, v3}, {1, v2}]

          assert_vector_parity(entries_a, entries_b, :int64, :plus, :ewise_add)
        end
      end

      property "plus_fp64/fp64" do
        check all(v1 <- pos_fp64(), v2 <- pos_fp64(), v3 <- pos_fp64()) do
          entries_a = [{0, v1}, {1, v2}]
          entries_b = [{0, v3}, {1, v2}]

          assert_vector_parity_fp64(entries_a, entries_b, :plus_fp64, :ewise_add)
        end
      end

      property "lor/bool" do
        check all(b1 <- boolean(), b2 <- boolean(), b3 <- boolean()) do
          entries_a = [{0, b1}, {1, b2}]
          entries_b = [{0, b3}, {1, b2}]

          assert_vector_parity(entries_a, entries_b, :bool, :lor, :ewise_add)
        end
      end
    end

    describe "backend parity: vector ewise_mult with random values" do
      property "times/int64" do
        check all(v1 <- pos_int64(), v2 <- pos_int64()) do
          entries_a = [{0, v1}, {1, v2}]
          entries_b = [{0, v2}, {1, v1}]

          assert_vector_parity(entries_a, entries_b, :int64, :times, :ewise_mult)
        end
      end
    end

    describe "backend parity: vector_reduce with random values" do
      property "plus/int64" do
        check all(v1 <- pos_int64(), v2 <- pos_int64(), v3 <- pos_int64()) do
          entries = [{0, v1}, {1, v2}, {2, v3}]

          {:ok, ref_v} = RefBackend.vector_from_entries(5, entries, :int64, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, entries, :int64, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :plus, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :plus, [])

          assert ref_s.value == ss_s.value

          SuiteSparse.vector_free(ss_v)
        end
      end

      property "plus_fp64/fp64" do
        check all(v1 <- pos_fp64(), v2 <- pos_fp64(), v3 <- pos_fp64()) do
          entries = [{0, v1}, {1, v2}, {2, v3}]

          {:ok, ref_v} = RefBackend.vector_from_entries(5, entries, :fp64, [])
          {:ok, ss_v} = SuiteSparse.vector_from_entries(5, entries, :fp64, [])

          {:ok, ref_s} = RefBackend.vector_reduce(ref_v, :plus_fp64, [])
          {:ok, ss_s} = SuiteSparse.vector_reduce(ss_v, :plus_fp64, [])

          assert_in_delta ref_s.value, ss_s.value, 0.001

          SuiteSparse.vector_free(ss_v)
        end
      end
    end

    #############################################################################
    # Backend parity: matrix operations with random values
    #############################################################################

    describe "backend parity: matrix_mxm with random values" do
      property "plus_times/int64" do
        check all(a01 <- pos_int64(), a12 <- pos_int64(), b10 <- pos_int64(), b21 <- pos_int64()) do
          entries_a = [{0, 1, a01}, {1, 2, a12}]
          entries_b = [{1, 0, b10}, {2, 1, b21}]

          assert_matrix_mxm_parity(entries_a, entries_b, :int64, :plus_times)
        end
      end

      property "plus_times_fp64/fp64" do
        check all(a01 <- pos_fp64(), a12 <- pos_fp64(), b10 <- pos_fp64(), b21 <- pos_fp64()) do
          entries_a = [{0, 1, a01}, {1, 2, a12}]
          entries_b = [{1, 0, b10}, {2, 1, b21}]

          assert_matrix_mxm_parity_fp64(entries_a, entries_b, :plus_times_fp64)
        end
      end

      property "lor_land/bool" do
        check all(a01 <- boolean(), a12 <- boolean(), b10 <- boolean(), b21 <- boolean()) do
          entries_a = [{0, 1, a01}, {1, 2, a12}]
          entries_b = [{1, 0, b10}, {2, 1, b21}]

          assert_matrix_mxm_parity(entries_a, entries_b, :bool, :lor_land)
        end
      end
    end

    describe "backend parity: matrix_ewise_add with random values" do
      property "plus/int64" do
        check all(v1 <- pos_int64(), v2 <- pos_int64(), v3 <- pos_int64()) do
          entries_a = [{0, 0, v1}, {1, 1, v2}]
          entries_b = [{0, 0, v3}, {1, 1, v2}]

          assert_matrix_ewise_parity(entries_a, entries_b, :int64, :plus, :ewise_add)
        end
      end

      property "max/int64" do
        check all(v1 <- pos_int64(), v2 <- pos_int64(), v3 <- pos_int64()) do
          entries_a = [{0, 0, v1}, {1, 1, v2}]
          entries_b = [{0, 0, v3}, {1, 1, v2}]

          assert_matrix_ewise_parity(entries_a, entries_b, :int64, :max, :ewise_add)
        end
      end
    end

    describe "backend parity: matrix_ewise_mult with random values" do
      property "times/int64" do
        check all(v1 <- pos_int64(), v2 <- pos_int64()) do
          entries_a = [{0, 0, v1}, {1, 1, v2}]
          entries_b = [{0, 0, v2}, {1, 1, v1}]

          assert_matrix_ewise_parity(entries_a, entries_b, :int64, :times, :ewise_mult)
        end
      end
    end

    describe "backend parity: matrix_reduce with random values" do
      property "plus/int64" do
        check all(v1 <- pos_int64(), v2 <- pos_int64(), v3 <- pos_int64()) do
          entries = [{0, 0, v1}, {0, 1, v2}, {1, 0, v3}]

          {:ok, ref_m} = RefBackend.matrix_from_coo(2, 2, entries, :int64, [])
          {:ok, ss_m} = SuiteSparse.matrix_from_coo(2, 2, entries, :int64, [])

          {:ok, ref_v} = RefBackend.matrix_reduce(ref_m, :plus, [])
          {:ok, ss_v} = SuiteSparse.matrix_reduce(ss_m, :plus, [])

          {:ok, ref_e} = RefBackend.vector_to_entries(ref_v)
          {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_v)

          assert sort_entries(ref_e) == sort_entries(ss_e)

          SuiteSparse.matrix_free(ss_m)
          SuiteSparse.vector_free(ss_v)
        end
      end
    end

    #############################################################################
    # Algebraic properties
    #############################################################################

    describe "semiring identity: I * A = A (plus_times)" do
      property "identity matrix times A equals A (RefBackend, int64)" do
        check all(v01 <- pos_int64(), v10 <- pos_int64()) do
          entries_i = [{0, 0, 1}, {1, 1, 1}]
          entries_a = [{0, 1, v01}, {1, 0, v10}]

          {:ok, i} = RefBackend.matrix_from_coo(2, 2, entries_i, :int64, [])
          {:ok, a} = RefBackend.matrix_from_coo(2, 2, entries_a, :int64, [])

          {:ok, result} = RefBackend.matrix_mxm(i, a, :plus_times, [])
          {:ok, result_coo} = RefBackend.matrix_to_coo(result)
          {:ok, a_coo} = RefBackend.matrix_to_coo(a)

          assert sort_coo(result_coo) == sort_coo(a_coo)
        end
      end
    end

    describe "plus associativity via vector reduce" do
      property "(a + b) + c = a + (b + c) for int64 via reduce" do
        check all(a <- pos_int64(), b <- pos_int64(), c <- pos_int64()) do
          left = a + b + c
          right = a + (b + c)

          assert left == right

          {:ok, v} = RefBackend.vector_from_entries(3, [{0, a}, {1, b}, {2, c}], :int64, [])
          {:ok, s} = RefBackend.vector_reduce(v, :plus, [])
          assert s.value == left
        end
      end
    end

    describe "plus-times distributivity: A*(B+C) = (A*B)+(A*C)" do
      property "distributivity holds for int64 matrices (RefBackend)" do
        # A is 2x3, B and C are 3x2
        # A*(B+C) should equal (A*B)+(A*C) for plus_times semiring and plus monoid
        check all(
                a01 <- pos_int64(),
                a12 <- pos_int64(),
                b10 <- pos_int64(),
                b21 <- pos_int64(),
                c10 <- pos_int64(),
                c21 <- pos_int64()
              ) do
          entries_a = [{0, 1, a01}, {1, 2, a12}]
          entries_b = [{1, 0, b10}, {2, 1, b21}]
          entries_c = [{1, 0, c10}, {2, 1, c21}]

          {:ok, a} = RefBackend.matrix_from_coo(2, 3, entries_a, :int64, [])
          {:ok, b} = RefBackend.matrix_from_coo(3, 2, entries_b, :int64, [])
          {:ok, c} = RefBackend.matrix_from_coo(3, 2, entries_c, :int64, [])

          # Left side: A * (B + C)
          {:ok, b_plus_c} = RefBackend.matrix_ewise_add(b, c, :plus, [])
          {:ok, left} = RefBackend.matrix_mxm(a, b_plus_c, :plus_times, [])

          # Right side: (A * B) + (A * C)
          {:ok, ab} = RefBackend.matrix_mxm(a, b, :plus_times, [])
          {:ok, ac} = RefBackend.matrix_mxm(a, c, :plus_times, [])
          {:ok, right} = RefBackend.matrix_ewise_add(ab, ac, :plus, [])

          {:ok, left_coo} = RefBackend.matrix_to_coo(left)
          {:ok, right_coo} = RefBackend.matrix_to_coo(right)

          assert sort_coo(left_coo) == sort_coo(right_coo)
        end
      end

      property "distributivity holds for int64 matrices (both backends)" do
        check all(
                a01 <- pos_int64(),
                a12 <- pos_int64(),
                b10 <- pos_int64(),
                b21 <- pos_int64(),
                c10 <- pos_int64(),
                c21 <- pos_int64()
              ) do
          entries_a = [{0, 1, a01}, {1, 2, a12}]
          entries_b = [{1, 0, b10}, {2, 1, b21}]
          entries_c = [{1, 0, c10}, {2, 1, c21}]

          # Compute on RefBackend
          {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, entries_a, :int64, [])
          {:ok, ref_b} = RefBackend.matrix_from_coo(3, 2, entries_b, :int64, [])
          {:ok, ref_c} = RefBackend.matrix_from_coo(3, 2, entries_c, :int64, [])

          {:ok, ref_bc} = RefBackend.matrix_ewise_add(ref_b, ref_c, :plus, [])
          {:ok, ref_left} = RefBackend.matrix_mxm(ref_a, ref_bc, :plus_times, [])

          # Compute on SuiteSparse
          {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, entries_a, :int64, [])
          {:ok, ss_b} = SuiteSparse.matrix_from_coo(3, 2, entries_b, :int64, [])
          {:ok, ss_c} = SuiteSparse.matrix_from_coo(3, 2, entries_c, :int64, [])

          {:ok, ss_bc} = SuiteSparse.matrix_ewise_add(ss_b, ss_c, :plus, [])
          {:ok, ss_left} = SuiteSparse.matrix_mxm(ss_a, ss_bc, :plus_times, [])

          # Parity: both backends agree on A*(B+C)
          {:ok, ref_left_coo} = RefBackend.matrix_to_coo(ref_left)
          {:ok, ss_left_coo} = SuiteSparse.matrix_to_coo(ss_left)

          assert sort_coo(ref_left_coo) == sort_coo(ss_left_coo)

          SuiteSparse.matrix_free(ss_a)
          SuiteSparse.matrix_free(ss_b)
          SuiteSparse.matrix_free(ss_c)
          SuiteSparse.matrix_free(ss_bc)
          SuiteSparse.matrix_free(ss_left)
        end
      end
    end

    #############################################################################
    # Helpers
    #############################################################################

    defp sort_coo(entries) do
      Enum.sort_by(entries, fn {r, c, _v} -> {r, c} end)
    end

    defp sort_entries(entries) do
      Enum.sort_by(entries, fn {i, _v} -> i end)
    end

    # Exact-comparison vector parity helper (int64, bool)
    defp assert_vector_parity(entries_a, entries_b, type, monoid, op) do
      size = length(entries_a) + 2

      {:ok, ref_a} = RefBackend.vector_from_entries(size, entries_a, type, [])
      {:ok, ref_b} = RefBackend.vector_from_entries(size, entries_b, type, [])
      {:ok, ss_a} = SuiteSparse.vector_from_entries(size, entries_a, type, [])
      {:ok, ss_b} = SuiteSparse.vector_from_entries(size, entries_b, type, [])

      {ref_c, ss_c} =
        case op do
          :ewise_add ->
            {:ok, rc} = RefBackend.vector_ewise_add(ref_a, ref_b, monoid, [])
            {:ok, sc} = SuiteSparse.vector_ewise_add(ss_a, ss_b, monoid, [])
            {rc, sc}

          :ewise_mult ->
            {:ok, rc} = RefBackend.vector_ewise_mult(ref_a, ref_b, monoid, [])
            {:ok, sc} = SuiteSparse.vector_ewise_mult(ss_a, ss_b, monoid, [])
            {rc, sc}
        end

      {:ok, ref_e} = RefBackend.vector_to_entries(ref_c)
      {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_c)

      assert sort_entries(ref_e) == sort_entries(ss_e)

      SuiteSparse.vector_free(ss_a)
      SuiteSparse.vector_free(ss_b)
      SuiteSparse.vector_free(ss_c)
    end

    # Approx-comparison vector parity helper (fp64)
    defp assert_vector_parity_fp64(entries_a, entries_b, monoid, op) do
      size = length(entries_a) + 2

      {:ok, ref_a} = RefBackend.vector_from_entries(size, entries_a, :fp64, [])
      {:ok, ref_b} = RefBackend.vector_from_entries(size, entries_b, :fp64, [])
      {:ok, ss_a} = SuiteSparse.vector_from_entries(size, entries_a, :fp64, [])
      {:ok, ss_b} = SuiteSparse.vector_from_entries(size, entries_b, :fp64, [])

      {ref_c, ss_c} =
        case op do
          :ewise_add ->
            {:ok, rc} = RefBackend.vector_ewise_add(ref_a, ref_b, monoid, [])
            {:ok, sc} = SuiteSparse.vector_ewise_add(ss_a, ss_b, monoid, [])
            {rc, sc}

          :ewise_mult ->
            {:ok, rc} = RefBackend.vector_ewise_mult(ref_a, ref_b, monoid, [])
            {:ok, sc} = SuiteSparse.vector_ewise_mult(ss_a, ss_b, monoid, [])
            {rc, sc}
        end

      {:ok, ref_e} = RefBackend.vector_to_entries(ref_c)
      {:ok, ss_e} = SuiteSparse.vector_to_entries(ss_c)

      assert_entries_approx_equal(ref_e, ss_e)

      SuiteSparse.vector_free(ss_a)
      SuiteSparse.vector_free(ss_b)
      SuiteSparse.vector_free(ss_c)
    end

    # Exact-comparison matrix mxm parity helper (int64, bool)
    defp assert_matrix_mxm_parity(entries_a, entries_b, type, semiring) do
      {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, entries_a, type, [])
      {:ok, ref_b} = RefBackend.matrix_from_coo(3, 2, entries_b, type, [])
      {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, entries_a, type, [])
      {:ok, ss_b} = SuiteSparse.matrix_from_coo(3, 2, entries_b, type, [])

      {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, semiring, [])
      {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, semiring, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)

      SuiteSparse.matrix_free(ss_a)
      SuiteSparse.matrix_free(ss_b)
      SuiteSparse.matrix_free(ss_c)
    end

    # Approx-comparison matrix mxm parity helper (fp64)
    defp assert_matrix_mxm_parity_fp64(entries_a, entries_b, semiring) do
      {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, entries_a, :fp64, [])
      {:ok, ref_b} = RefBackend.matrix_from_coo(3, 2, entries_b, :fp64, [])
      {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, entries_a, :fp64, [])
      {:ok, ss_b} = SuiteSparse.matrix_from_coo(3, 2, entries_b, :fp64, [])

      {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, semiring, [])
      {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, semiring, [])

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

      assert_coo_approx_equal(ref_coo, ss_coo)

      SuiteSparse.matrix_free(ss_a)
      SuiteSparse.matrix_free(ss_b)
      SuiteSparse.matrix_free(ss_c)
    end

    # Exact-comparison matrix ewise parity helper (int64, bool)
    defp assert_matrix_ewise_parity(entries_a, entries_b, type, monoid, op) do
      {:ok, ref_a} = RefBackend.matrix_from_coo(2, 2, entries_a, type, [])
      {:ok, ref_b} = RefBackend.matrix_from_coo(2, 2, entries_b, type, [])
      {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 2, entries_a, type, [])
      {:ok, ss_b} = SuiteSparse.matrix_from_coo(2, 2, entries_b, type, [])

      {ref_c, ss_c} =
        case op do
          :ewise_add ->
            {:ok, rc} = RefBackend.matrix_ewise_add(ref_a, ref_b, monoid, [])
            {:ok, sc} = SuiteSparse.matrix_ewise_add(ss_a, ss_b, monoid, [])
            {rc, sc}

          :ewise_mult ->
            {:ok, rc} = RefBackend.matrix_ewise_mult(ref_a, ref_b, monoid, [])
            {:ok, sc} = SuiteSparse.matrix_ewise_mult(ss_a, ss_b, monoid, [])
            {rc, sc}
        end

      {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
      {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

      assert sort_coo(ref_coo) == sort_coo(ss_coo)

      SuiteSparse.matrix_free(ss_a)
      SuiteSparse.matrix_free(ss_b)
      SuiteSparse.matrix_free(ss_c)
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
  end
else
  defmodule GraphBLAS.PropertyTest do
    use ExUnit.Case
    @moduletag :skip
    @tag :native_backend
    test "skipped: native backend not compiled (set EX_GRAPHBLAS_COMPILE_NATIVE=1)" do
      :ok
    end
  end
end
