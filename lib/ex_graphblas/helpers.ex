defmodule GraphBLAS.Helpers do
  @moduledoc false

  alias GraphBLAS.Backend.Elixir, as: ElixirBackend
  alias GraphBLAS.{Matrix, Scalar, Vector}

  @doc """
  Normalizes result values into `{:ok, val}` tuples.

  Handles the common pattern where functions return either `{:ok, val}`,
  bare structs, or `{:error, reason}`.
  """
  @spec ok({:ok, term()} | Matrix.t() | Vector.t() | Scalar.t() | {:error, term()} | :ok) ::
          {:ok, term()} | {:error, term()} | :ok
  def ok({:ok, val}), do: {:ok, val}
  def ok(%Matrix{} = m), do: {:ok, m}
  def ok(%Vector{} = v), do: {:ok, v}
  def ok(%Scalar{} = s), do: {:ok, s}
  def ok({:error, _} = err), do: err
  def ok(:ok), do: :ok

  @doc """
  Frees backend resources for containers.

  For Elixir backend, this is a no-op. For backends that export
  `matrix_free`/`vector_free` (e.g. SuiteSparse), calls the appropriate
  free function. For other backends, no-op.
  """
  @spec maybe_free(Matrix.t() | Vector.t(), module()) :: :ok
  def maybe_free(_container, ElixirBackend), do: :ok

  def maybe_free(%Matrix{} = m, backend) do
    if Code.ensure_loaded?(backend) and function_exported?(backend, :matrix_free, 1) do
      backend.matrix_free(m)
    else
      :ok
    end
  end

  def maybe_free(%Vector{} = v, backend) do
    if Code.ensure_loaded?(backend) and function_exported?(backend, :vector_free, 1) do
      backend.vector_free(v)
    else
      :ok
    end
  end

  def maybe_free(_container, _backend), do: :ok
end
