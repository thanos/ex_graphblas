defmodule GraphBLAS.Backend do
  @moduledoc """
  Behaviour that defines the contract for GraphBLAS computation backends.

  Every backend must implement this behaviour. The public API modules
  (`GraphBLAS.Matrix`, `GraphBLAS.Vector`, etc.) dispatch to the
  resolved backend rather than performing computation themselves. This
  separation ensures that:

  - The public API remains stable and backend-neutral.
  - New backends (native, port, reference) can be added without changing
    calling code.
  - Backend-specific details (NIF resource lifecycles, port protocols)
    stay behind the boundary.

  ## Backend lifecycle

  Backends are stateless modules. Container data (matrices, vectors) carries
  its backend identity in its struct, specifically in the `:data` field
  which is opaque and backend-specific. A reference backend stores Elixir
  maps; a native backend stores NIF resource references.

  The calling pattern is:

      GraphBLAS.Matrix.from_coo(3, 3, entries)
      # Resolves backend via config, calls:
      backend.matrix_from_coo(3, 3, entries, :int64, [])

  Backends do not need to be started or supervised. They are plain modules
  that implement the callbacks. State that persists across calls (such as
  native initialization) is the backend's own responsibility and should be
  handled through the native layer's standard mechanisms (e.g., on-first-call
  initialization via `:persistent_term` or a gen_server).

  ## Opaque data convention

  The `:data` field in Matrix and Vector structs is **opaque to calling code**.
  Backends can store any term there. The only requirement is that the backend
  can interpret its own data. You must not pattern-match on `:data` outside
  the backend module.

  ## Phase 1 scope

  This behaviour defines the full callback surface needed for Phase 1
  operations. Not all callbacks need working implementations in every
  backend; a backend may return `{:error, {:unsupported_operation, ...}}`
  for callbacks it does not yet support. The Reference backend implements
  all callbacks listed here.
  """

  alias GraphBLAS.Types

  @typedoc """
  Backend-specific opaque data stored in the `:data` field of containers.

  For the Reference backend, this is a map containing sparse entries
  and metadata. For the SuiteSparse backend, this will be a NIF resource
  reference. Calling code must not inspect or pattern-match on this value.
  """
  @type backend_data :: term()

  #############################################################################
  # Matrix callbacks
  #############################################################################

  @doc """
  Creates an empty matrix with the given dimensions and scalar type.

  Returns `{:ok, matrix}` on success or `{:error, GraphBLAS.Error.t()}` on failure.
  """
  @callback matrix_new(
              nrows :: non_neg_integer(),
              ncols :: non_neg_integer(),
              type :: Types.scalar_type(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Matrix.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Creates a sparse matrix from COO (coordinate) triples.

  `entries` is a list of `{row, col, value}` tuples. Duplicate entries
  (same row, col) are combined using the provided monoid's operator
  (defaulting to addition).
  """
  @callback matrix_from_coo(
              nrows :: non_neg_integer(),
              ncols :: non_neg_integer(),
              entries :: [Types.coo_entry()],
              type :: Types.scalar_type(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Matrix.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Returns the number of stored (non-default) values in the matrix.

  In a sparse matrix, "stored values" means the explicit entries, not
  the implicit zeros.
  """
  @callback matrix_nvals(matrix :: GraphBLAS.Matrix.t()) ::
              {:ok, non_neg_integer()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Returns `{nrows, ncols}` the dimensions of the matrix.
  """
  @callback matrix_shape(matrix :: GraphBLAS.Matrix.t()) ::
              {:ok, Types.shape()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Returns the scalar type of the matrix's stored values.
  """
  @callback matrix_type(matrix :: GraphBLAS.Matrix.t()) ::
              {:ok, Types.scalar_type()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Extracts the stored entries of a matrix as COO triples.

  Returns a sorted list of `{row, col, value}` tuples.
  """
  @callback matrix_to_coo(matrix :: GraphBLAS.Matrix.t()) ::
              {:ok, [Types.coo_entry()]} | {:error, GraphBLAS.Error.t()}

  @doc """
  Multiplies two matrices using the given semiring.

  `semiring` can be an atom naming a built-in semiring (e.g., `:plus_times`)
  or a struct defining a custom semiring. The result matrix `C = A * B`
  has shape `{nrows(A), ncols(B)}`.
  """
  @callback matrix_mxm(
              a :: GraphBLAS.Matrix.t(),
              b :: GraphBLAS.Matrix.t(),
              semiring :: atom() | GraphBLAS.Semiring.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Matrix.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Multiplies a matrix by a vector using the given semiring.

  The result vector `v = A * x` has length `nrows(A)`.
  """
  @callback matrix_mxv(
              matrix :: GraphBLAS.Matrix.t(),
              vector :: GraphBLAS.Vector.t(),
              semiring :: atom() | GraphBLAS.Semiring.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Element-wise addition of two matrices using the given monoid.

  The result has the union of the structural nonzero positions, with
  overlapping positions combined using the monoid's binary operator.
  """
  @callback matrix_ewise_add(
              a :: GraphBLAS.Matrix.t(),
              b :: GraphBLAS.Matrix.t(),
              monoid :: atom() | GraphBLAS.Monoid.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Matrix.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Element-wise multiplication of two matrices using the given monoid.

  The result has only positions that are structural nonzeros in both
  operands, with values combined using the monoid's binary operator
  (which for multiplication is typically `times`).
  """
  @callback matrix_ewise_mult(
              a :: GraphBLAS.Matrix.t(),
              b :: GraphBLAS.Matrix.t(),
              monoid :: atom() | GraphBLAS.Monoid.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Matrix.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Reduces a matrix to a vector along rows (or columns, per descriptor).

  Each element of the result vector is the monoid reduction of the
  corresponding row (or column) of the input matrix.
  """
  @callback matrix_reduce(
              matrix :: GraphBLAS.Matrix.t(),
              monoid :: atom() | GraphBLAS.Monoid.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Returns the transpose of a matrix.
  """
  @callback matrix_transpose(matrix :: GraphBLAS.Matrix.t(), opts :: Types.opts()) ::
              {:ok, GraphBLAS.Matrix.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Converts a sparse matrix to a dense list-of-lists representation.

  Returns `{:ok, [[value]]}` where each inner list is a row. Default values
  (typically zero) fill positions that are structural zeros in the sparse
  representation.

  This is a debugging and inspection helper, not intended for production use
  on large matrices.
  """
  @callback matrix_to_dense(matrix :: GraphBLAS.Matrix.t()) ::
              {:ok, [[term()]]} | {:error, GraphBLAS.Error.t()}

  #############################################################################
  # Vector callbacks
  #############################################################################

  @doc """
  Creates an empty vector with the given size and scalar type.
  """
  @callback vector_new(
              size :: non_neg_integer(),
              type :: Types.scalar_type(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Creates a sparse vector from index-value pairs.

  `entries` is a list of `{index, value}` tuples.
  """
  @callback vector_from_entries(
              size :: non_neg_integer(),
              entries :: [Types.vector_entry()],
              type :: Types.scalar_type(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Returns the number of stored (non-default) values in the vector.
  """
  @callback vector_nvals(vector :: GraphBLAS.Vector.t()) ::
              {:ok, non_neg_integer()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Returns the size (declared length) of the vector.
  """
  @callback vector_size(vector :: GraphBLAS.Vector.t()) ::
              {:ok, non_neg_integer()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Returns the scalar type of the vector's stored values.
  """
  @callback vector_type(vector :: GraphBLAS.Vector.t()) ::
              {:ok, Types.scalar_type()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Extracts the stored entries of a vector as index-value pairs.
  """
  @callback vector_to_entries(vector :: GraphBLAS.Vector.t()) ::
              {:ok, [Types.vector_entry()]} | {:error, GraphBLAS.Error.t()}

  @doc """
  Multiplies a vector by a matrix (from the left) using the given semiring.

  The result vector `v = x^T * A` has length `ncols(A)`.
  """
  @callback vector_vxm(
              vector :: GraphBLAS.Vector.t(),
              matrix :: GraphBLAS.Matrix.t(),
              semiring :: atom() | GraphBLAS.Semiring.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Element-wise addition of two vectors using the given monoid.
  """
  @callback vector_ewise_add(
              a :: GraphBLAS.Vector.t(),
              b :: GraphBLAS.Vector.t(),
              monoid :: atom() | GraphBLAS.Monoid.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Element-wise multiplication of two vectors using the given monoid.
  """
  @callback vector_ewise_mult(
              a :: GraphBLAS.Vector.t(),
              b :: GraphBLAS.Vector.t(),
              monoid :: atom() | GraphBLAS.Monoid.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Reduces a vector to a scalar using the given monoid.

  Returns the monoid reduction of all stored values.
  """
  @callback vector_reduce(
              vector :: GraphBLAS.Vector.t(),
              monoid :: atom() | GraphBLAS.Monoid.t(),
              opts :: Types.opts()
            ) ::
              {:ok, GraphBLAS.Scalar.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Converts a sparse vector to a dense list representation.

  Returns `{:ok, [value]}` where the list has length equal to the vector's
  declared size. Default values (typically zero) fill positions that are
  structural zeros in the sparse representation.

  This is a debugging and inspection helper, not intended for production use
  on large vectors.
  """
  @callback vector_to_list(vector :: GraphBLAS.Vector.t()) ::
              {:ok, [term()]} | {:error, GraphBLAS.Error.t()}

  #############################################################################
  # Container manipulation callbacks
  #############################################################################

  @doc """
  Sets the value at position (row, col) in the matrix.

  If the position already has a stored value, it is overwritten.
  If the position was a structural zero, it becomes a stored entry.
  Returns `{:ok, matrix}` with the updated matrix.
  """
  @callback matrix_set(
              matrix :: GraphBLAS.Matrix.t(),
              row :: non_neg_integer(),
              col :: non_neg_integer(),
              value :: term()
            ) ::
              {:ok, GraphBLAS.Matrix.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Extracts the value at position (row, col) from the matrix.

  Returns `{:ok, value}` for stored entries.
  For structural zeros (positions with no stored entry), returns the default
  value for the matrix's type (0 for `:int64`, 0.0 for `:fp64`, false for `:bool`).
  """
  @callback matrix_extract(
              matrix :: GraphBLAS.Matrix.t(),
              row :: non_neg_integer(),
              col :: non_neg_integer()
            ) ::
              {:ok, term()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Creates a deep copy of the matrix.

  The copy is independent — modifying it does not affect the original.
  For the SuiteSparse backend, this creates a new C object with a new pointer.
  """
  @callback matrix_dup(matrix :: GraphBLAS.Matrix.t()) ::
              {:ok, GraphBLAS.Matrix.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Sets the value at the given index in the vector.

  If the index already has a stored value, it is overwritten.
  Returns `{:ok, vector}` with the updated vector.
  """
  @callback vector_set(
              vector :: GraphBLAS.Vector.t(),
              index :: non_neg_integer(),
              value :: term()
            ) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Extracts the value at the given index from the vector.

  Returns `{:ok, value}` for stored entries.
  For structural zeros (indices with no stored entry), returns the default
  value for the vector's type.
  """
  @callback vector_extract(
              vector :: GraphBLAS.Vector.t(),
              index :: non_neg_integer()
            ) ::
              {:ok, term()} | {:error, GraphBLAS.Error.t()}

  @doc """
  Creates a deep copy of the vector.

  The copy is independent — modifying it does not affect the original.
  """
  @callback vector_dup(vector :: GraphBLAS.Vector.t()) ::
              {:ok, GraphBLAS.Vector.t()} | {:error, GraphBLAS.Error.t()}
end
