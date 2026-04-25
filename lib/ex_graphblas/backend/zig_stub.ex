defmodule GraphBLAS.Backend.ZigStub do
  @moduledoc """
  Zigler integration test backend.

  This backend verifies that Zigler compiles and loads NIFs correctly
  on a given Elixir/OTP combination. It implements the
  `GraphBLAS.Backend` behaviour with lightweight operations backed by
  `GraphBLAS.Nif.ZigStub` and returns
  `{:error, {:unsupported_operation, __MODULE__}}` for compute-heavy
  callbacks that would require SuiteSparse:GraphBLAS.

  ## Purpose

  1. **CI verification** -- proves Zigler works on the target Elixir/OTP
     without requiring SuiteSparse:GraphBLAS to be installed.

  2. **Backend contract validation** -- ensures every `@callback` in
     `GraphBLAS.Backend` has an implementation, so the compiler catches
     missing functions when new callbacks are added.

  ## Configuration

      config :ex_graphblas,
        default_backend: GraphBLAS.Backend.ZigStub

  This is primarily useful in CI. For development and testing, use
  `GraphBLAS.Backend.Elixir`. For production, use
  `GraphBLAS.Backend.SuiteSparse`.
  """

  @behaviour GraphBLAS.Backend

  alias GraphBLAS.{Error, Matrix, Nif.ZigStub, Vector}

  @unsupported {:error,
                %Error{
                  reason: {:unsupported_operation, __MODULE__},
                  message: "ZigStub backend does not implement this operation",
                  context: %{}
                }}

  #############################################################################
  # Zigler verification
  #############################################################################

  @doc """
  Returns `true` if the Zig stub NIF loaded successfully.
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(ZigStub) and function_exported?(ZigStub, :ping, 0)
  end

  @doc """
  Calls the Zig stub `add_one/1` NIF.
  """
  @spec add_one(integer()) :: {:ok, integer()} | {:error, term()}
  def add_one(n) when is_integer(n) do
    {:ok, ZigStub.add_one(n)}
  rescue
    error -> {:error, error}
  end

  @doc """
  Calls the Zig stub `ping/0` NIF.
  """
  @spec ping() :: {:ok, :ok} | {:error, term()}
  def ping do
    {:ok, ZigStub.ping()}
  rescue
    error -> {:error, error}
  end

  #############################################################################
  # Matrix callbacks (lightweight operations only)
  #############################################################################

  @impl GraphBLAS.Backend
  def matrix_new(nrows, ncols, type, _opts) when nrows >= 0 and ncols >= 0 do
    {:ok,
     %Matrix{
       shape: {nrows, ncols},
       type: type,
       data: %{zig_stub: true, entries: %{}},
       backend: __MODULE__
     }}
  end

  def matrix_new(nrows, ncols, _type, _opts),
    do:
      Error.error(
        {:invalid_argument, "dimensions must be non-negative, got {#{nrows}, #{ncols}}"}
      )

  @impl GraphBLAS.Backend
  def matrix_nvals(%Matrix{data: %{entries: entries}}) do
    {:ok, map_size(entries)}
  end

  @impl GraphBLAS.Backend
  def matrix_shape(%Matrix{shape: shape}) do
    {:ok, shape}
  end

  @impl GraphBLAS.Backend
  def matrix_type(%Matrix{type: type}) do
    {:ok, type}
  end

  @impl GraphBLAS.Backend
  def matrix_from_coo(_nrows, _ncols, _entries, _type, _opts), do: @unsupported
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
  def matrix_set(_matrix, _row, _col, _value), do: @unsupported
  @impl GraphBLAS.Backend
  def matrix_extract(_matrix, _row, _col), do: @unsupported
  @impl GraphBLAS.Backend
  def matrix_dup(_matrix), do: @unsupported

  #############################################################################
  # Vector callbacks (lightweight operations only)
  #############################################################################

  @impl GraphBLAS.Backend
  def vector_new(size, type, _opts) when size >= 0 do
    {:ok,
     %Vector{
       size: size,
       type: type,
       data: %{zig_stub: true, entries: %{}},
       backend: __MODULE__
     }}
  end

  def vector_new(size, _type, _opts),
    do: Error.error({:invalid_argument, "vector size must be non-negative, got #{size}"})

  @impl GraphBLAS.Backend
  def vector_nvals(%Vector{data: %{entries: entries}}) do
    {:ok, map_size(entries)}
  end

  @impl GraphBLAS.Backend
  def vector_size(%Vector{size: size}) do
    {:ok, size}
  end

  @impl GraphBLAS.Backend
  def vector_type(%Vector{type: type}) do
    {:ok, type}
  end

  @impl GraphBLAS.Backend
  def vector_from_entries(_size, _entries, _type, _opts), do: @unsupported
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
  @impl GraphBLAS.Backend
  def vector_set(_vector, _index, _value), do: @unsupported
  @impl GraphBLAS.Backend
  def vector_extract(_vector, _index), do: @unsupported
  @impl GraphBLAS.Backend
  def vector_dup(_vector), do: @unsupported
end
