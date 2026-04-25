defmodule GraphBLAS.ZigStubTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.ZigStub

  setup do
    if ZigStub.available?() do
      :ok
    else
      {:skip, "ZigStub NIF not available (ensure Zig toolchain is installed)"}
    end
  end

  test "ZigStub backend is available" do
    assert ZigStub.available?()
  end

  test "add_one/1 increments an integer via Zig NIF" do
    assert {:ok, 42} = ZigStub.add_one(41)
  end

  test "ping/0 returns :ok via Zig NIF" do
    assert {:ok, :ok} = ZigStub.ping()
  end

  test "matrix_new/4 creates a stub matrix" do
    assert {:ok, %GraphBLAS.Matrix{}} = ZigStub.matrix_new(3, 4, :int64, [])
  end

  test "matrix_shape/1 returns dimensions" do
    {:ok, m} = ZigStub.matrix_new(3, 4, :int64, [])
    assert {:ok, {3, 4}} = ZigStub.matrix_shape(m)
  end

  test "matrix_type/1 returns the scalar type" do
    {:ok, m} = ZigStub.matrix_new(3, 4, :fp64, [])
    assert {:ok, :fp64} = ZigStub.matrix_type(m)
  end

  test "vector_new/3 creates a stub vector" do
    assert {:ok, %GraphBLAS.Vector{}} = ZigStub.vector_new(5, :int64, [])
  end

  test "vector_size/1 returns the declared size" do
    {:ok, v} = ZigStub.vector_new(5, :int64, [])
    assert {:ok, 5} = ZigStub.vector_size(v)
  end

  test "compute operations return unsupported" do
    {:ok, a} = ZigStub.matrix_new(2, 2, :int64, [])
    {:ok, b} = ZigStub.matrix_new(2, 2, :int64, [])

    assert {:error, %GraphBLAS.Error{reason: {:unsupported_operation, GraphBLAS.Backend.ZigStub}}} =
             ZigStub.matrix_mxm(a, b, :plus_times, [])
  end
end
