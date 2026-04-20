defmodule GraphBLAS.Backend.SuiteSparse do
  @moduledoc """
  SuiteSparse:GraphBLAS backend (placeholder for Phase 2).

  This module defines the backend that will delegate to SuiteSparse:GraphBLAS
  via Zigler NIFs. It is included in Phase 1 as a structural placeholder
  so that:

  1. The backend selection mechanism can reference it by module name.
  2. The configuration system can list it as a known backend.
  3. The architectural boundary is clear from day one.

  All callbacks currently return `{:error, {:unsupported_operation, ...}}`
  because native NIF integration is Phase 2 work.
  """

  @behaviour GraphBLAS.Backend

  alias GraphBLAS.Error

  @unsupported {:error,
                %Error{
                  reason: {:unsupported_operation, :not_yet_implemented, __MODULE__},
                  message: "SuiteSparse backend will be implemented in Phase 2",
                  context: %{}
                }}

  @impl GraphBLAS.Backend
  def matrix_new(_nrows, _ncols, _type, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_from_coo(_nrows, _ncols, _entries, _type, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_nvals(_matrix), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_shape(_matrix), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_type(_matrix), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_to_coo(_matrix), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_mxm(_a, _b, _semiring, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_mxv(_matrix, _vector, _semiring, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_ewise_add(_a, _b, _monoid, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_ewise_mult(_a, _b, _monoid, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_reduce(_matrix, _monoid, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_transpose(_matrix, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def matrix_to_dense(_matrix), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_new(_size, _type, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_from_entries(_size, _entries, _type, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_nvals(_vector), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_size(_vector), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_type(_vector), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_to_entries(_vector), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_vxm(_vector, _matrix, _semiring, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_ewise_add(_a, _b, _monoid, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_ewise_mult(_a, _b, _monoid, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_reduce(_vector, _monoid, _opts), do: @unsupported

  @impl GraphBLAS.Backend
  def vector_to_list(_vector), do: @unsupported
end
