defmodule GraphBLAS.Vector do
  @moduledoc """
  Sparse vector operations for GraphBLAS.

  A sparse vector stores only its non-default entries. In GraphBLAS,
  vectors are the one-dimensional counterpart to sparse matrices and
  serve as both operands and results in many graph algorithms.

  ## Construction

  Create a vector from index-value pairs:

      {:ok, v} = GraphBLAS.Vector.from_entries(4, [{0, 1.0}, {2, 3.0}], :fp64)

  Or create an empty vector:

      {:ok, v} = GraphBLAS.Vector.new(4, :int64)

  ## Struct design

  The `%Vector{}` struct carries:
  - `:size` -- the declared length of the vector
  - `:type` -- the scalar type of stored values
  - `:data` -- opaque backend-specific data (do not pattern-match on this)
  """

  alias GraphBLAS.{Backend, Config, Error, Types}

  @type t :: %__MODULE__{
          size: non_neg_integer(),
          type: Types.scalar_type(),
          backend: module(),
          data: Backend.backend_data()
        }

  @enforce_keys [:size, :type, :data]
  defstruct [:size, :type, :backend, :data]

  @doc """
  Creates an empty sparse vector with the given size and scalar type.
  """
  @spec new(non_neg_integer(), Types.scalar_type(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def new(size, type \\ :int64, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.vector_new(size, type, opts)
  end

  @doc """
  Creates a sparse vector from index-value pairs.

  `entries` is a list of `{index, value}` tuples with zero-based indices.
  """
  @spec from_entries(non_neg_integer(), [Types.vector_entry()], Types.scalar_type(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def from_entries(size, entries, type \\ :int64, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.vector_from_entries(size, entries, type, opts)
  end

  @doc """
  Returns the declared length of the vector.
  """
  @spec size(t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def size(%__MODULE__{} = vector) do
    {:ok, vector.size}
  end

  @doc """
  Returns the scalar type of the vector's stored values.
  """
  @spec type(t()) :: {:ok, Types.scalar_type()} | {:error, Error.t()}
  def type(%__MODULE__{} = vector) do
    {:ok, vector.type}
  end

  @doc """
  Returns the number of stored (non-default) values in the vector.

  Dispatches to the backend that created the vector.
  """
  @spec nvals(t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def nvals(%__MODULE__{backend: nil} = vector),
    do: nvals(%{vector | backend: Config.default_backend()})

  def nvals(%__MODULE__{backend: backend} = vector) do
    backend.vector_nvals(vector)
  end

  @doc """
  Extracts the stored entries as `{index, value}` pairs.

  Dispatches to the backend that created the vector.
  """
  @spec to_entries(t()) :: {:ok, [Types.vector_entry()]} | {:error, Error.t()}
  def to_entries(%__MODULE__{backend: nil} = vector),
    do: to_entries(%{vector | backend: Config.default_backend()})

  def to_entries(%__MODULE__{backend: backend} = vector) do
    backend.vector_to_entries(vector)
  end

  @doc """
  Multiplies a vector by a matrix (from the left) using the given semiring.

  The result vector `v = x^T * A` has length `ncols(A)`.
  """
  @spec vxm(t(), GraphBLAS.Matrix.t(), atom() | GraphBLAS.Semiring.t(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def vxm(
        %__MODULE__{} = vector,
        %GraphBLAS.Matrix{} = matrix,
        semiring \\ :plus_times,
        opts \\ []
      ) do
    backend = Config.resolve_backend(opts)
    backend.vector_vxm(vector, matrix, semiring, opts)
  end

  @doc """
  Element-wise addition of two vectors using the given monoid.
  """
  @spec ewise_add(t(), t(), atom() | GraphBLAS.Monoid.t(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def ewise_add(%__MODULE__{} = a, %__MODULE__{} = b, monoid \\ :plus, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.vector_ewise_add(a, b, monoid, opts)
  end

  @doc """
  Element-wise multiplication of two vectors using the given monoid.
  """
  @spec ewise_mult(t(), t(), atom() | GraphBLAS.Monoid.t(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def ewise_mult(%__MODULE__{} = a, %__MODULE__{} = b, monoid \\ :times, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.vector_ewise_mult(a, b, monoid, opts)
  end

  @doc """
  Reduces a vector to a scalar using the given monoid.
  """
  @spec reduce(t(), atom() | GraphBLAS.Monoid.t(), Types.opts()) ::
          {:ok, GraphBLAS.Scalar.t()} | {:error, Error.t()}
  def reduce(%__MODULE__{} = vector, monoid \\ :plus, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.vector_reduce(vector, monoid, opts)
  end

  @doc """
  Converts a sparse vector to a dense list representation.

  Returns `{:ok, list}` where the list has length equal to the vector's
  declared size. Positions that are structural zeros in the sparse
  representation are filled with the default value for the vector's type.

  This is a debugging and inspection helper. Do not use on large vectors.

  ## Examples

      iex> {:ok, v} = GraphBLAS.Vector.from_entries(4, [{0, 5}, {2, 3}], :int64)
      iex> {:ok, list} = GraphBLAS.Vector.to_list(v)
      iex> list
      [5, 0, 3, 0]

  """
  @spec to_list(t()) :: {:ok, [term()]} | {:error, Error.t()}
  def to_list(%__MODULE__{backend: nil} = vector),
    do: to_list(%{vector | backend: Config.default_backend()})

  def to_list(%__MODULE__{backend: backend} = vector) do
    backend.vector_to_list(vector)
  end

  @doc """
  Sets the value at the given index in the vector, overwriting any existing value.

  ## Examples

      iex> {:ok, v} = GraphBLAS.Vector.from_entries(3, [{0, 1}], :int64)
      iex> {:ok, v} = GraphBLAS.Vector.set(v, 1, 5)
      iex> {:ok, 5} = GraphBLAS.Vector.extract(v, 1)

  """
  @spec set(t(), non_neg_integer(), term(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def set(vector, index, value, opts \\ [])

  def set(%__MODULE__{backend: nil} = vector, index, value, opts),
    do: set(%{vector | backend: Config.default_backend()}, index, value, opts)

  def set(%__MODULE__{backend: backend} = vector, index, value, _opts) do
    backend.vector_set(vector, index, value)
  end

  @doc """
  Extracts the value at the given index from the vector.

  Returns the default value (0, 0.0, or false) for structural zeros.

  ## Examples

      iex> {:ok, v} = GraphBLAS.Vector.from_entries(3, [{0, 42}], :int64)
      iex> {:ok, 42} = GraphBLAS.Vector.extract(v, 0)
      iex> {:ok, 0} = GraphBLAS.Vector.extract(v, 1)

  """
  @spec extract(t(), non_neg_integer(), Types.opts()) ::
          {:ok, term()} | {:error, Error.t()}
  def extract(vector, index, opts \\ [])

  def extract(%__MODULE__{backend: nil} = vector, index, opts),
    do: extract(%{vector | backend: Config.default_backend()}, index, opts)

  def extract(%__MODULE__{backend: backend} = vector, index, _opts) do
    backend.vector_extract(vector, index)
  end

  @doc """
  Creates a deep copy of the vector.

  The copy is independent — modifying it does not affect the original.

  ## Examples

      iex> {:ok, v} = GraphBLAS.Vector.from_entries(3, [{0, 1}], :int64)
      iex> {:ok, copy} = GraphBLAS.Vector.dup(v)
      iex> {:ok, 1} = GraphBLAS.Vector.extract(v, 0)

  """
  @spec dup(t(), Types.opts()) :: {:ok, t()} | {:error, Error.t()}
  def dup(%__MODULE__{} = vector, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.vector_dup(vector)
  end
end
