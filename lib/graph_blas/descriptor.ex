defmodule GraphBLAS.Descriptor do
  @moduledoc """
  Descriptor type definition for GraphBLAS.

  A **descriptor** controls how a GraphBLAS operation interprets its
  inputs and writes its output. Descriptors are the GraphBLAS mechanism
  for modifying operation semantics without creating new operation
  variants.

  ## What descriptors control

  In GraphBLAS C, a descriptor has fields that modify each operand:

  - **Input modifiers**: transpose the input (`:inp0_transpose`,
    `:inp1_transpose`), or apply a structural/complement mask.
  - **Output modifiers**: replace (overwrite) the output instead of
    merging, or restrict writes via a mask.
  - **Mask modifiers**: complement the mask, or use the mask's structure
    vs. its values.

  ## Phase 1 scope

  Phase 1 defines the Descriptor type with a minimal set of options.
  Full descriptor support (transpose inputs, replace output, complement
  mask) is planned for Phase 4. The Reference backend currently
  recognizes descriptors but may not implement all modifiers until then.

  ## Usage (conceptual)

      # In Phase 4, descriptors will be passed to operations:
      {:ok, c} = GraphBLAS.Matrix.mxm(a, b, :plus_times,
        descriptor: GraphBLAS.Descriptor.new(inp0_transpose: true)
      )

  Instead of creating `A_transposed` as a separate matrix, you tell
  the operation to treat `A` as if it were transposed. This avoids
  a copy and is more efficient.
  """

  @type transpose_input :: :none | :transpose
  @type output_mode :: :merge | :replace
  @type mask_mode :: :structural | :value

  @type t :: %__MODULE__{
          inp0_transpose: transpose_input(),
          inp1_transpose: transpose_input(),
          output: output_mode(),
          mask: mask_mode()
        }

  @enforce_keys []
  defstruct inp0_transpose: :none,
            inp1_transpose: :none,
            output: :merge,
            mask: :structural

  @doc """
  Creates a new descriptor with the given options.

  All fields have sensible defaults that result in standard (unmodified)
  operation semantics.

  ## Options

  - `:inp0_transpose` -- `:none` (default) or `:transpose` to transpose
    the first input before the operation.
  - `:inp1_transpose` -- `:none` (default) or `:transpose` to transpose
    the second input before the operation.
  - `:output` -- `:merge` (default) to merge results into the output, or
    `:replace` to clear the output before writing.
  - `:mask` -- `:structural` (default) to use the mask's structure, or
    `:value` to use the mask's values.

  ## Examples

      iex> GraphBLAS.Descriptor.new()
      %GraphBLAS.Descriptor{inp0_transpose: :none, inp1_transpose: :none, output: :merge, mask: :structural}

      iex> GraphBLAS.Descriptor.new(inp0_transpose: :transpose)
      %GraphBLAS.Descriptor{inp0_transpose: :transpose, inp1_transpose: :none, output: :merge, mask: :structural}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      inp0_transpose: Keyword.get(opts, :inp0_transpose, :none),
      inp1_transpose: Keyword.get(opts, :inp1_transpose, :none),
      output: Keyword.get(opts, :output, :merge),
      mask: Keyword.get(opts, :mask, :structural)
    }
  end

  @doc """
  Returns a descriptor that transposes the first input.
  """
  @spec inp0_transpose() :: t()
  def inp0_transpose, do: new(inp0_transpose: :transpose)

  @doc """
  Returns a descriptor that transposes the second input.
  """
  @spec inp1_transpose() :: t()
  def inp1_transpose, do: new(inp1_transpose: :transpose)

  @doc """
  Returns a descriptor that replaces the output instead of merging.
  """
  @spec replace_output() :: t()
  def replace_output, do: new(output: :replace)
end
