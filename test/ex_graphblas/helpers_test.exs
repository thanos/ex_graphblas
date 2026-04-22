defmodule GraphBLAS.HelpersTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.Elixir, as: ElixirBackend
  alias GraphBLAS.Backend.SuiteSparse
  alias GraphBLAS.{Error, Helpers, Matrix, Scalar, Vector}

  describe "ok/1" do
    test "passes through {:ok, val} tuples unchanged" do
      assert {:ok, 42} = Helpers.ok({:ok, 42})
      assert {:ok, :atom} = Helpers.ok({:ok, :atom})
      assert {:ok, [1, 2, 3]} = Helpers.ok({:ok, [1, 2, 3]})
      assert {:ok, %{key: :value}} = Helpers.ok({:ok, %{key: :value}})
    end

    test "wraps Matrix structs in {:ok, ...}" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64)
      assert {:ok, ^m} = Helpers.ok(m)
    end

    test "wraps Vector structs in {:ok, ...}" do
      {:ok, v} = Vector.from_entries(3, [{0, 1}], :int64)
      assert {:ok, ^v} = Helpers.ok(v)
    end

    test "wraps Scalar structs in {:ok, ...}" do
      s = Scalar.new(42, :int64)
      assert {:ok, ^s} = Helpers.ok(s)
    end

    test "passes through {:error, ...} tuples unchanged" do
      err = {:error, :some_reason}
      assert ^err = Helpers.ok(err)
    end

    test "passes through Error structs in error tuples" do
      err_struct = Error.new({:dimension_mismatch, {3, 3}, {2, 2}})
      err_tuple = {:error, err_struct}
      assert ^err_tuple = Helpers.ok(err_tuple)
    end

    test "passes through :ok atom unchanged" do
      assert :ok = Helpers.ok(:ok)
    end

    test "works in with chains for error propagation" do
      result =
        with {:ok, m} <- Helpers.ok(Matrix.from_coo(2, 2, [{0, 0, 1}], :int64)),
             {:ok, v} <- Helpers.ok(Vector.from_entries(2, [{0, 1}], :int64)) do
          {:ok, {m, v}}
        end

      assert {:ok, {%Matrix{}, %Vector{}}} = result
    end

    test "stops with chain on error" do
      result =
        with {:ok, _m} <- Helpers.ok(Matrix.from_coo(2, 2, [{0, 0, 1}], :int64)),
             {:ok, _v} <- Helpers.ok({:error, :test_error}),
             {:ok, _other} <- Helpers.ok(:ok) do
          {:ok, :should_not_reach}
        end

      assert {:error, :test_error} = result
    end
  end

  describe "maybe_free/2" do
    test "is no-op for Elixir backend with Matrix" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64, backend: ElixirBackend)
      assert :ok = Helpers.maybe_free(m, ElixirBackend)

      # Matrix should still be valid after "free"
      assert {:ok, 1} = Matrix.nvals(m)
    end

    test "is no-op for Elixir backend with Vector" do
      {:ok, v} = Vector.from_entries(3, [{0, 1}], :int64, backend: ElixirBackend)
      assert :ok = Helpers.maybe_free(v, ElixirBackend)

      # Vector should still be valid after "free"
      assert {:ok, 1} = Vector.nvals(v)
    end

    test "frees SuiteSparse Matrix resources" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64, backend: SuiteSparse)
      assert :ok = Helpers.maybe_free(m, SuiteSparse)

      # After freeing, accessing the freed resource would cause issues
      # (we don't test this as it would crash the test)
    end

    test "frees SuiteSparse Vector resources" do
      {:ok, v} = Vector.from_entries(3, [{0, 1}], :int64, backend: SuiteSparse)
      assert :ok = Helpers.maybe_free(v, SuiteSparse)

      # After freeing, accessing the freed resource would cause issues
      # (we don't test this as it would crash the test)
    end

    test "is no-op for unknown backend with Matrix" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64, backend: ElixirBackend)
      # Pass a fake backend module
      assert :ok = Helpers.maybe_free(m, FakeBackend)
    end

    test "is no-op for unknown backend with Vector" do
      {:ok, v} = Vector.from_entries(3, [{0, 1}], :int64, backend: ElixirBackend)
      # Pass a fake backend module
      assert :ok = Helpers.maybe_free(v, FakeBackend)
    end

    test "handles nil backend gracefully" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64, backend: ElixirBackend)
      assert :ok = Helpers.maybe_free(m, nil)
    end

    test "can be called multiple times on same container (idempotent for Elixir)" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64, backend: ElixirBackend)
      assert :ok = Helpers.maybe_free(m, ElixirBackend)
      assert :ok = Helpers.maybe_free(m, ElixirBackend)
      assert :ok = Helpers.maybe_free(m, ElixirBackend)

      # Still usable
      assert {:ok, 1} = Matrix.nvals(m)
    end

    test "frees SuiteSparse Matrix and Vector in same call" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64, backend: SuiteSparse)
      {:ok, v} = Vector.from_entries(3, [{0, 1}], :int64, backend: SuiteSparse)

      assert :ok = Helpers.maybe_free(m, SuiteSparse)
      assert :ok = Helpers.maybe_free(v, SuiteSparse)
    end
  end

  describe "ok/1 with complex nesting" do
    test "handles nested {:ok, {:ok, val}}" do
      assert {:ok, {:ok, 42}} = Helpers.ok({:ok, {:ok, 42}})
    end

    test "handles nested errors" do
      assert {:error, {:inner, :error}} = Helpers.ok({:error, {:inner, :error}})
    end

    test "works with multiple struct types in sequence" do
      {:ok, m} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64)
      {:ok, v} = Vector.from_entries(2, [{0, 1}], :int64)
      s = Scalar.new(42, :int64)

      assert {:ok, ^m} = Helpers.ok(m)
      assert {:ok, ^v} = Helpers.ok(v)
      assert {:ok, ^s} = Helpers.ok(s)
    end
  end

  describe "maybe_free/2 edge cases" do
    test "handles arbitrary container with arbitrary backend" do
      # Non-Matrix/Vector container
      assert :ok = Helpers.maybe_free(:not_a_container, SomeBackend)
      assert :ok = Helpers.maybe_free("string", ElixirBackend)
      assert :ok = Helpers.maybe_free(%{custom: :struct}, SuiteSparse)
    end

    test "handles Matrix with wrong backend field type" do
      # Matrix with backend: :atom instead of module
      m_with_bad_backend = %Matrix{
        shape: {2, 2},
        type: :int64,
        backend: :not_a_module,
        data: %{entries: %{}, nrows: 2, ncols: 2, type: :int64}
      }

      assert :ok = Helpers.maybe_free(m_with_bad_backend, :not_a_module)
    end
  end

  describe "integration with algorithm patterns" do
    test "ok/1 integrates with typical algorithm error handling" do
      result =
        with {:ok, m} <- Helpers.ok(Matrix.from_coo(2, 2, [{0, 0, 1}], :int64)),
             {:ok, m2} <- Helpers.ok(Matrix.from_coo(2, 2, [{1, 1, 1}], :int64)),
             {:ok, result} <- Helpers.ok(Matrix.mxm(m, m2, :plus_times)) do
          Helpers.ok(Matrix.to_coo(result))
        end

      assert {:ok, []} = result
    end

    test "maybe_free/2 integrates with typical algorithm cleanup" do
      backend = ElixirBackend
      {:ok, m1} = Matrix.from_coo(2, 2, [{0, 0, 1}], :int64, backend: backend)
      {:ok, m2} = Matrix.from_coo(2, 2, [{1, 1, 1}], :int64, backend: backend)
      {:ok, result} = Matrix.mxm(m1, m2, :plus_times, backend: backend)

      # Typical algorithm pattern: free intermediates
      :ok = Helpers.maybe_free(m1, backend)
      :ok = Helpers.maybe_free(m2, backend)

      # Result is still valid
      assert {:ok, 0} = Matrix.nvals(result)
    end
  end
end
