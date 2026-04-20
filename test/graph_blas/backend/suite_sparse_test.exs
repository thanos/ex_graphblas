defmodule GraphBLAS.SuiteSparseBackendTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.SuiteSparse

  describe "all callbacks" do
    test "return unsupported error" do
      assert {:error,
              %GraphBLAS.Error{
                reason:
                  {:unsupported_operation, :not_yet_implemented, GraphBLAS.Backend.SuiteSparse}
              }} =
               SuiteSparse.matrix_new(3, 3, :int64, [])

      assert {:error,
              %GraphBLAS.Error{
                reason:
                  {:unsupported_operation, :not_yet_implemented, GraphBLAS.Backend.SuiteSparse}
              }} =
               SuiteSparse.matrix_from_coo(3, 3, [], :int64, [])

      assert {:error,
              %GraphBLAS.Error{
                reason:
                  {:unsupported_operation, :not_yet_implemented, GraphBLAS.Backend.SuiteSparse}
              }} =
               SuiteSparse.vector_new(5, :int64, [])
    end
  end
end
