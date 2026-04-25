defmodule GraphBLAS.Types do
  @moduledoc """
  Shared type definitions for GraphBLAS.

  This module centralizes all public typespecs so they can be referenced
  consistently across the library. The types here define the vocabulary
  of the GraphBLAS algebraic model as it appears at the Elixir boundary.

  ## Scalar types

  GraphBLAS operates on typed containers. The supported scalar types
  correspond to the numeric kinds needed for sparse linear algebra:

  - `:bool`    -- boolean values (0 or 1, structural or valued)
  - `:int8`    -- signed 8-bit integer
  - `:int16`   -- signed 16-bit integer
  - `:int32`   -- signed 32-bit integer
  - `:int64`   -- signed 64-bit integer (default for integer data)
  - `:uint8`   -- unsigned 8-bit integer
  - `:uint16`  -- unsigned 16-bit integer
  - `:uint32`  -- unsigned 32-bit integer
  - `:uint64`  -- unsigned 64-bit integer
  - `:fp32`    -- 32-bit IEEE float
  - `:fp64`    -- 64-bit IEEE float (default for floating-point data)

  These map directly to SuiteSparse:GraphBLAS type codes and are chosen
  to align with Nx type conventions where practical.

  ## Design note

  We define our own type atoms rather than reusing Nx types because
  GraphBLAS must remain Nx-independent at its core. The type names
  are chosen to be familiar to Nx users while preserving GraphBLAS
  semantics (for example, unsigned integer types are first-class in
  GraphBLAS but rare in typical tensor libraries).
  """

  @typedoc """
  A scalar type that can be stored in a GraphBLAS container.

  This type determines the element representation for matrices and vectors.
  When a type is not specified, `:int64` is the default integer type and
  `:fp64` is the default floating-point type, matching GraphBLAS conventions.
  """
  @type scalar_type ::
          :bool
          | :int8
          | :int16
          | :int32
          | :int64
          | :uint8
          | :uint16
          | :uint32
          | :uint64
          | :fp32
          | :fp64

  @typedoc """
  A pair of dimensions for a matrix: `{rows, columns}`.

  Both dimensions must be non-negative. A matrix of size `{0, 0}` is valid
  and represents an empty container.
  """
  @type shape :: {non_neg_integer(), non_neg_integer()}

  @typedoc """
  A zero-based index into a matrix dimension or vector.

  GraphBLAS uses zero-based indexing throughout, matching the C convention.
  This differs from Elixir's one-based indexing convention; the choice is
  deliberate to preserve GraphBLAS semantics and enable direct mapping to
  the underlying C API without index translation.
  """
  @type index :: non_neg_integer()

  @typedoc """
  A COO (coordinate format) entry: `{row_index, col_index, value}`.

  This is the primary sparse construction format for matrices in Phase 1.
  The entries are stored as tuples for clarity and pattern-matching
  convenience. Duplicate indices in the same entry list are resolved
  according to the monoid provided at construction time (duplicates
  are combined using the monoid's operator, defaulting to addition).
  """
  @type coo_entry :: {index(), index(), number() | boolean()}

  @typedoc """
  A sparse vector entry: `{index, value}`.
  """
  @type vector_entry :: {index(), number() | boolean()}

  @typedoc """
  Options keyword list for matrix or vector operations.

  Common options include:

  - `:backend` -- the backend module to use (overrides the default)
  - `:type` -- the scalar type for a new container
  - `:mask` -- a mask to apply to the operation
  - `:descriptor` -- a descriptor controlling operation semantics
  """
  @type opts :: keyword()

  @doc """
  Returns the default scalar type for integer data.

  This is `:int64`, matching the GraphBLAS convention.
  """
  @spec default_int_type :: :int64
  def default_int_type, do: :int64

  @doc """
  Returns the default scalar type for floating-point data.

  This is `:fp64`, matching the GraphBLAS convention.
  """
  @spec default_fp_type :: :fp64
  def default_fp_type, do: :fp64

  @doc """
  Returns the default scalar type for boolean data.
  """
  @spec default_bool_type :: :bool
  def default_bool_type, do: :bool

  @doc """
  Validates that the given atom is a supported scalar type.

  Only `:int64`, `:fp64`, and `:bool` are currently supported by both backends.

  Returns `:ok` if valid, or `{:error, {:unsupported_type, term}}` otherwise.
  """
  @spec validate_scalar_type(term()) :: :ok | {:error, {:unsupported_type, term()}}
  def validate_scalar_type(type) when type in [:int64, :fp64, :bool] do
    :ok
  end

  def validate_scalar_type(other) do
    {:error, {:unsupported_type, other}}
  end

  @doc """
  Returns the default scalar type based on the kind of values provided.

  For integer values, defaults to `:int64`. For float values, defaults
  to `:fp64`. For boolean values, defaults to `:bool`.

  This is a heuristic for convenience. When the type matters for
  correctness, specify it explicitly.
  """
  @spec infer_type([number() | boolean()]) :: scalar_type()
  def infer_type([]), do: :int64

  def infer_type(values) do
    cond do
      Enum.all?(values, &is_boolean/1) -> :bool
      Enum.any?(values, &is_float/1) -> :fp64
      true -> :int64
    end
  end

  @doc """
  Returns the size in bytes of a single element of the given scalar type.

  Useful for estimating memory requirements before allocating large containers.
  """
  @spec type_size(scalar_type()) :: pos_integer()
  def type_size(:bool), do: 1
  def type_size(:int8), do: 1
  def type_size(:int16), do: 2
  def type_size(:int32), do: 4
  def type_size(:int64), do: 8
  def type_size(:uint8), do: 1
  def type_size(:uint16), do: 2
  def type_size(:uint32), do: 4
  def type_size(:uint64), do: 8
  def type_size(:fp32), do: 4
  def type_size(:fp64), do: 8
end
