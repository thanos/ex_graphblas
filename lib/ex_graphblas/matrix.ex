defmodule GraphBLAS.Matrix do
  @moduledoc """
  Sparse matrix operations for GraphBLAS.

  A sparse matrix stores only its computed (non-default) values.
  In GraphBLAS terminology, the "default" value is typically zero
  (though it can be other values depending on the monoid in use).
  This representation makes matrix operations on graphs efficient:
  most graphs have adjacency matrices that are overwhelmingly sparse.

  ## Construction

  The primary way to create a matrix in Phase 1 is from COO
  (coordinate) triples:

      {:ok, m} = GraphBLAS.Matrix.from_coo(4, 4, [
        {0, 1, 1}, {1, 2, 1}, {2, 3, 1}, {3, 0, 1}
      ])

  You can also create an empty matrix and populate it later:

      {:ok, m} = GraphBLAS.Matrix.new(4, 4, :int64)

  ## Struct design

  The `%Matrix{}` struct carries:
  - `:shape` -- the `{nrows, ncols}` dimensions
  - `:type` -- the scalar type of stored values
  - `:data` -- opaque backend-specific data (do not pattern-match on this)

  The `:data` field is intentionally opaque. Different backends store
  different representations: the Reference backend uses maps, while a
  native backend will store NIF resource references. You must not access
  `:data` directly; use the API functions instead.
  """

  alias GraphBLAS.{Backend, Config, Error, Types}

  @type t :: %__MODULE__{
          shape: Types.shape(),
          type: Types.scalar_type(),
          backend: module(),
          data: Backend.backend_data()
        }

  @enforce_keys [:shape, :type, :data]
  defstruct [:shape, :type, :backend, :data]

  @doc """
  Creates an empty sparse matrix with the given dimensions and scalar type.

  The matrix will have no stored values. This is useful when you need
  a container before populating it.

  ## Examples

      iex> {:ok, m} = GraphBLAS.Matrix.new(3, 3, :int64)
      iex> GraphBLAS.Matrix.shape(m)
      {:ok, {3, 3}}

      iex> GraphBLAS.Matrix.nvals(m)
      {:ok, 0}

  """
  @spec new(non_neg_integer(), non_neg_integer(), Types.scalar_type(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def new(nrows, ncols, type \\ :int64, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.matrix_new(nrows, ncols, type, opts)
  end

  @doc """
  Creates a sparse matrix from COO (coordinate) triples.

  `entries` is a list of `{row, col, value}` tuples, where `row` and
  `col` are zero-based indices. Duplicate entries at the same position
  are combined using the additive monoid for the scalar type (integers
  are summed, floats are summed, booleans are OR'd).

  ## Examples

      iex> entries = [{0, 1, 1}, {1, 2, 2}, {2, 0, 3}]
      iex> {:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, entries, :int64)
      iex> GraphBLAS.Matrix.shape(m)
      {:ok, {3, 3}}

      iex> GraphBLAS.Matrix.nvals(m)
      {:ok, 3}

  ## Errors

  - `{:error, {:index_out_of_bounds, ...}}` if any index exceeds the dimensions
  - `{:error, {:dimension_mismatch, ...}}` if dimensions are invalid

  """
  @spec from_coo(
          non_neg_integer(),
          non_neg_integer(),
          [Types.coo_entry()],
          Types.scalar_type(),
          Types.opts()
        ) ::
          {:ok, t()} | {:error, Error.t()}
  def from_coo(nrows, ncols, entries, type \\ :int64, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.matrix_from_coo(nrows, ncols, entries, type, opts)
  end

  @doc """
  Returns the `{nrows, ncols}` dimensions of the matrix.
  """
  @spec shape(t()) :: {:ok, Types.shape()} | {:error, Error.t()}
  def shape(%__MODULE__{} = matrix) do
    {:ok, matrix.shape}
  end

  @doc """
  Returns the scalar type of the matrix's stored values.
  """
  @spec type(t()) :: {:ok, Types.scalar_type()} | {:error, Error.t()}
  def type(%__MODULE__{} = matrix) do
    {:ok, matrix.type}
  end

  @doc """
  Returns the number of stored (non-default) values in the matrix.

  In a sparse matrix, this is the count of explicitly stored entries,
  not the product of dimensions.

  Dispatches to the backend that created the matrix.
  """
  @spec nvals(t()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def nvals(%__MODULE__{backend: nil} = matrix),
    do: nvals(%{matrix | backend: Config.default_backend()})

  def nvals(%__MODULE__{backend: backend} = matrix) do
    backend.matrix_nvals(matrix)
  end

  @doc """
  Extracts the stored entries as COO triples `{row, col, value}`.

  Returns a sorted list of the non-default entries. The sort order is
  row-major (row first, then column).

  Dispatches to the backend that created the matrix.
  """
  @spec to_coo(t()) :: {:ok, [Types.coo_entry()]} | {:error, Error.t()}
  def to_coo(%__MODULE__{backend: nil} = matrix),
    do: to_coo(%{matrix | backend: Config.default_backend()})

  def to_coo(%__MODULE__{backend: backend} = matrix) do
    backend.matrix_to_coo(matrix)
  end

  @doc """
  Multiplies two matrices using the given semiring.

  `semiring` can be an atom naming a built-in semiring (e.g.,
  `:plus_times`, `:max_plus`, `:min_plus`) or a `%Semiring{}` struct.

  The result `C = A * B` has shape `{nrows(A), ncols(B)}` and type
  determined by the semiring's output type.

  ## Examples

      iex> {:ok, a} = GraphBLAS.Matrix.from_coo(2, 3, [{0, 1, 1}, {1, 2, 1}], :int64)
      iex> {:ok, b} = GraphBLAS.Matrix.from_coo(3, 2, [{1, 0, 1}, {2, 1, 1}], :int64)
      iex> {:ok, c} = GraphBLAS.Matrix.mxm(a, b, :plus_times)
      iex> GraphBLAS.Matrix.shape(c)
      {:ok, {2, 2}}

  ## Errors

  - `{:error, {:dimension_mismatch, ...}}` if `ncols(A) != nrows(B)`

  """
  @spec mxm(t(), t(), atom() | GraphBLAS.Semiring.t(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def mxm(%__MODULE__{} = a, %__MODULE__{} = b, semiring \\ :plus_times, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.matrix_mxm(a, b, semiring, opts)
  end

  @doc """
  Multiplies a matrix by a vector using the given semiring.

  The result vector `v = A * x` has length `nrows(A)`.
  """
  @spec mxv(t(), GraphBLAS.Vector.t(), atom() | GraphBLAS.Semiring.t(), Types.opts()) ::
          {:ok, GraphBLAS.Vector.t()} | {:error, Error.t()}
  def mxv(
        %__MODULE__{} = matrix,
        %GraphBLAS.Vector{} = vector,
        semiring \\ :plus_times,
        opts \\ []
      ) do
    backend = Config.resolve_backend(opts)
    backend.matrix_mxv(matrix, vector, semiring, opts)
  end

  @doc """
  Element-wise addition of two matrices using the given monoid.

  The result has the union of the structural nonzero positions, with
  overlapping positions combined using the monoid's binary operator.
  """
  @spec ewise_add(t(), t(), atom() | GraphBLAS.Monoid.t(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def ewise_add(%__MODULE__{} = a, %__MODULE__{} = b, monoid \\ :plus, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.matrix_ewise_add(a, b, monoid, opts)
  end

  @doc """
  Element-wise multiplication of two matrices using the given monoid.

  The result has only positions that are structural nonzeros in both
  operands, with values combined using the monoid's binary operator.
  """
  @spec ewise_mult(t(), t(), atom() | GraphBLAS.Monoid.t(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def ewise_mult(%__MODULE__{} = a, %__MODULE__{} = b, monoid \\ :times, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.matrix_ewise_mult(a, b, monoid, opts)
  end

  @doc """
  Reduces a matrix to a vector along the row dimension using the given monoid.

  Each element of the result vector is the monoid reduction of the
  corresponding row of the matrix. This is equivalent to multiplying
  by a vector of all ones under the given monoid.
  """
  @spec reduce(t(), atom() | GraphBLAS.Monoid.t(), Types.opts()) ::
          {:ok, GraphBLAS.Vector.t()} | {:error, Error.t()}
  def reduce(%__MODULE__{} = matrix, monoid \\ :plus, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.matrix_reduce(matrix, monoid, opts)
  end

  @doc """
  Returns the transpose of the matrix.

  The transpose matrix `A^T` has `shape(A^T) = (ncols(A), nrows(A))`
  and `A^T[j, i] = A[i, j]` for all stored positions.
  """
  @spec transpose(t(), Types.opts()) :: {:ok, t()} | {:error, Error.t()}
  def transpose(%__MODULE__{} = matrix, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.matrix_transpose(matrix, opts)
  end

  @doc """
  Converts a sparse matrix to a dense list-of-lists representation.

  Returns `{:ok, rows}` where `rows` is a list of rows, each row being
  a list of values. Positions that are structural zeros in the sparse
  representation are filled with the default value for the matrix's type.

  This is a debugging and inspection helper. Do not use on large matrices.

  ## Examples

      iex> {:ok, m} = GraphBLAS.Matrix.from_coo(2, 2, [{0, 0, 5}, {1, 1, 7}], :int64)
      iex> {:ok, dense} = GraphBLAS.Matrix.to_dense(m)
      iex> dense
      [[5, 0], [0, 7]]

  """
  @spec to_dense(t()) :: {:ok, [[term()]]} | {:error, Error.t()}
  def to_dense(%__MODULE__{backend: nil} = matrix),
    do: to_dense(%{matrix | backend: Config.default_backend()})

  def to_dense(%__MODULE__{backend: backend} = matrix) do
    backend.matrix_to_dense(matrix)
  end

  @doc """
  Sets the value at position (row, col) in the matrix, overwriting any existing value.

  ## Examples

      iex> {:ok, m} = GraphBLAS.Matrix.from_coo(2, 2, [{0, 0, 1}], :int64)
      iex> {:ok, m} = GraphBLAS.Matrix.set(m, 1, 1, 5)
      iex> {:ok, 5} = GraphBLAS.Matrix.extract(m, 1, 1)

  """
  @spec set(t(), non_neg_integer(), non_neg_integer(), term(), Types.opts()) ::
          {:ok, t()} | {:error, Error.t()}
  def set(matrix, row, col, value, opts \\ [])

  def set(%__MODULE__{backend: nil} = matrix, row, col, value, opts),
    do: set(%{matrix | backend: Config.default_backend()}, row, col, value, opts)

  def set(%__MODULE__{backend: backend} = matrix, row, col, value, _opts) do
    backend.matrix_set(matrix, row, col, value)
  end

  @doc """
  Extracts the value at position (row, col) from the matrix.

  Returns the default value (0, 0.0, or false) for structural zeros.

  ## Examples

      iex> {:ok, m} = GraphBLAS.Matrix.from_coo(2, 2, [{0, 0, 42}], :int64)
      iex> {:ok, 42} = GraphBLAS.Matrix.extract(m, 0, 0)
      iex> {:ok, 0} = GraphBLAS.Matrix.extract(m, 1, 1)

  """
  @spec extract(t(), non_neg_integer(), non_neg_integer(), Types.opts()) ::
          {:ok, term()} | {:error, Error.t()}
  def extract(matrix, row, col, opts \\ [])

  def extract(%__MODULE__{backend: nil} = matrix, row, col, opts),
    do: extract(%{matrix | backend: Config.default_backend()}, row, col, opts)

  def extract(%__MODULE__{backend: backend} = matrix, row, col, _opts) do
    backend.matrix_extract(matrix, row, col)
  end

  @doc """
  Creates a deep copy of the matrix.

  The copy is independent — modifying it does not affect the original.

  ## Examples

      iex> {:ok, m} = GraphBLAS.Matrix.from_coo(2, 2, [{0, 0, 1}], :int64)
      iex> {:ok, copy} = GraphBLAS.Matrix.dup(m)
      iex> {:ok, 1} = GraphBLAS.Matrix.extract(m, 0, 0)

  """
  @spec dup(t(), Types.opts()) :: {:ok, t()} | {:error, Error.t()}
  def dup(%__MODULE__{} = matrix, opts \\ []) do
    backend = Config.resolve_backend(opts)
    backend.matrix_dup(matrix)
  end
end
