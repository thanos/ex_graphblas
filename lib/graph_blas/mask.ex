defmodule GraphBLAS.Mask do
  @moduledoc """
  Mask type definition for GraphBLAS.

  A **mask** controls which positions in the output of a GraphBLAS
  operation are written to. Masks are fundamental to expressing graph
  algorithms efficiently: instead of creating a new result container
  for every intermediate step, masks allow you to restrict computation
  to the structural positions you care about.

  ## How masks work

  When a mask `M` is applied to an operation computing result `C`:

  - **Structural mask** (the default): only positions where `M` has
    a stored (structural) entry are written in `C`.
  - **Complement mask** (controlled by descriptor): only positions
    where `M` does *not* have a stored entry are written in `C`.

  Masks can be applied to matrices or vectors, and the mask type
  (matrix or vector) must match the output type of the operation.

  ## Phase 1 scope

  Phase 1 defines the Mask type but does not implement masked operations
  in the Reference backend. Full mask support is planned for Phase 4.

  ## Example (conceptual)

  Given a matrix `A` and a mask `M`:

      # Without mask: C = A + B writes to all positions
      # With mask M:  C = A + B (mask: M) writes only where M is structural

  This saves memory and computation in sparse graph algorithms.
  """

  alias GraphBLAS.{Matrix, Vector}

  @type mask_source :: Matrix.t() | Vector.t()

  @type t :: %__MODULE__{
          source: mask_source(),
          complement: boolean()
        }

  @enforce_keys [:source]
  defstruct [:source, complement: false]

  @doc """
  Creates a mask from a matrix or vector.

  By default, the mask is structural (complement: false), meaning
  only positions where the source has stored entries are written.

  ## Examples

      iex> {:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 0, 1}], :int64)
      iex> mask = GraphBLAS.Mask.new(m)
      %GraphBLAS.Mask{source: %GraphBLAS.Matrix{...}, complement: false}
  """
  @spec new(mask_source(), keyword()) :: t()
  def new(source, opts \\ []) do
    complement = Keyword.get(opts, :complement, false)
    %__MODULE__{source: source, complement: complement}
  end

  @doc """
  Creates a complement mask from a matrix or vector.

  A complement mask inverts the structural positions: only positions
  where the source does NOT have stored entries are written.
  """
  @spec complement(mask_source()) :: t()
  def complement(source) do
    %__MODULE__{source: source, complement: true}
  end

  @doc """
  Returns whether this mask is a complement mask.
  """
  @spec complement?(t()) :: boolean()
  def complement?(%__MODULE__{complement: c}), do: c

  @doc """
  Returns the source container (matrix or vector) underlying this mask.
  """
  @spec source(t()) :: mask_source()
  def source(%__MODULE__{source: s}), do: s
end
