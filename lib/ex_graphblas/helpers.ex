defmodule GraphBLAS.Helpers do
  @moduledoc false

  alias GraphBLAS.Backend.Elixir, as: ElixirBackend
  alias GraphBLAS.Backend.SuiteSparse
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
  Frees SuiteSparse backend resources for containers.

  For Elixir backend, this is a no-op. For SuiteSparse backend,
  calls the appropriate free function. For other backends, no-op.
  """
  @spec maybe_free(Matrix.t() | Vector.t(), module()) :: :ok
  def maybe_free(_container, ElixirBackend), do: :ok

  def maybe_free(%Matrix{} = m, SuiteSparse) do
    SuiteSparse.matrix_free(m)
  end

  def maybe_free(%Vector{} = v, SuiteSparse) do
    SuiteSparse.vector_free(v)
  end

  def maybe_free(_container, _backend), do: :ok
end
