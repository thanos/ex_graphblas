defmodule GraphBLAS.Scalar do
  @moduledoc """
  A scalar value with an associated GraphBLAS type.

  Scalars are the atomic elements of GraphBLAS computations. They appear
  as the result of reduction operations (e.g., reducing a vector to its
  sum) and can be used as implicit identities in some contexts.

  ## Design note

  In GraphBLAS C, scalars are first-class containers. In GraphBLAS,
  we represent them as a thin struct that pairs a value with its type.
  This avoids ambiguous type inference (e.g., the integer `0` could be
  `:int64` or `:int8`) while keeping the representation trivially simple.

  For most operations, you do not need to construct scalars directly;
  they are produced by reductions and consumed internally.
  """

  alias GraphBLAS.Types

  @type t :: %__MODULE__{
          type: Types.scalar_type(),
          value: number() | boolean()
        }

  @enforce_keys [:type, :value]
  defstruct [:type, :value]

  @doc """
  Creates a scalar with the given type and value.

  ## Examples

      iex> GraphBLAS.Scalar.new(:int64, 42)
      %GraphBLAS.Scalar{type: :int64, value: 42}

      iex> GraphBLAS.Scalar.new(:fp64, 3.14)
      %GraphBLAS.Scalar{type: :fp64, value: 3.14}

      iex> GraphBLAS.Scalar.new(:bool, true)
      %GraphBLAS.Scalar{type: :bool, value: true}
  """
  @spec new(Types.scalar_type(), number() | boolean()) :: t()
  def new(type, value) do
    %__MODULE__{type: type, value: value}
  end

  @doc """
  Returns the value wrapped by the scalar.

  ## Examples

      iex> GraphBLAS.Scalar.new(:int64, 42) |> GraphBLAS.Scalar.value()
      42
  """
  @spec value(t()) :: number() | boolean()
  def value(%__MODULE__{value: v}), do: v

  @doc """
  Returns the scalar type of the wrapped value.

  ## Examples

      iex> GraphBLAS.Scalar.new(:fp64, 1.0) |> GraphBLAS.Scalar.type()
      :fp64
  """
  @spec type(t()) :: Types.scalar_type()
  def type(%__MODULE__{type: t}), do: t

  @doc """
  Returns the zero (identity) value for the given monoid and scalar type.

  The zero/identity is the neutral element of the monoid's binary operator:
  - For `:plus` monoids: 0 (integer or float)
  - For `:times` monoids: 1 (integer or float)
  - For `:min` monoids: the maximum representable value of the type
  - For `:max` monoids: the minimum representable value of the type
  - For `:land` (logical and): true
  - For `:lor` (logical or): false
  """
  @spec zero(atom(), Types.scalar_type()) :: t()
  def zero(monoid, type)

  def zero(:plus, type), do: new(type, numeric_zero(type))
  def zero(:times, type), do: new(type, numeric_one(type))
  def zero(:min, type), do: new(type, type_max(type))
  def zero(:max, type), do: new(type, type_min(type))
  def zero(:land, :bool), do: new(:bool, true)
  def zero(:lor, :bool), do: new(:bool, false)

  defp numeric_zero(:bool), do: false
  defp numeric_zero(:fp32), do: 0.0
  defp numeric_zero(:fp64), do: 0.0
  defp numeric_zero(_int_type), do: 0

  defp numeric_one(:bool), do: true
  defp numeric_one(:fp32), do: 1.0
  defp numeric_one(:fp64), do: 1.0
  defp numeric_one(_int_type), do: 1

  defp type_max(:int8), do: 127
  defp type_max(:int16), do: 32_767
  defp type_max(:int32), do: 2_147_483_647
  defp type_max(:int64), do: 9_223_372_036_854_775_807
  defp type_max(:uint8), do: 255
  defp type_max(:uint16), do: 65_535
  defp type_max(:uint32), do: 4_294_967_295
  defp type_max(:uint64), do: 18_446_744_073_709_551_615
  defp type_max(:fp32), do: :math.pow(2, 127) * (2 - :math.pow(2, -23))
  defp type_max(:fp64), do: :math.pow(2, 1023) * (2 - :math.pow(2, -52))
  defp type_max(:bool), do: true

  defp type_min(:int8), do: -128
  defp type_min(:int16), do: -32_768
  defp type_min(:int32), do: -2_147_483_648
  defp type_min(:int64), do: -9_223_372_036_854_775_808
  defp type_min(:uint8), do: 0
  defp type_min(:uint16), do: 0
  defp type_min(:uint32), do: 0
  defp type_min(:uint64), do: 0
  defp type_min(:fp32), do: -:math.pow(2, 127) * (2 - :math.pow(2, -23))
  defp type_min(:fp64), do: -:math.pow(2, 1023) * (2 - :math.pow(2, -52))
  defp type_min(:bool), do: false
end
