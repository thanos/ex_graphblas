defmodule GraphBLAS.Monoid do
  @moduledoc """
  Monoid definitions for GraphBLAS.

  A **monoid** `(S, ⊕, 𝟎)` consists of:

  - A set `S` of values
  - An associative binary operator `⊕`
  - An identity element `𝟎` such that `a ⊕ 𝟎 = 𝟎 ⊕ a = a`

  Monoids are used in GraphBLAS for:
  - Element-wise addition (`ewise_add`) combines overlapping entries
  - Reduction (`reduce`) collapses a vector or matrix to a scalar
  - Duplicate entry resolution during matrix/vector construction

  ## Built-in monoids

  | Name      | Operator | Identity | Use                              |
  |-----------|----------|----------|----------------------------------|
  | `:plus`   | `a + b`  | `0`      | Sum reduction, duplicate merging |
  | `:times`  | `a * b`  | `1`      | Product reduction                |
  | `:min`    | `min(a,b)` | max(S) | Minimum reduction, shortest path |
  | `:max`    | `max(a,b)` | min(S) | Maximum reduction, critical path |
  | `:land`   | `a ∧ b`  | `true`   | Logical AND                      |
  | `:lor`    | `a ∨ b`  | `false`  | Logical OR                       |
  | `:lxor`   | `a ⊻ b`  | `false`  | Logical XOR                      |

  Each built-in monoid has typed variants (e.g., `:plus` for integers,
  `:plus_fp64` for doubles) to avoid implicit type ambiguity.
  """

  alias GraphBLAS.Types

  @type t :: %__MODULE__{
          name: atom(),
          operator: atom() | (term(), term() -> term()),
          identity: term(),
          type: Types.scalar_type()
        }

  @enforce_keys [:name, :operator, :identity, :type]
  defstruct [:name, :operator, :identity, :type]

  @doc """
  Creates a custom monoid struct.

  Prefer using built-in monoids by atom name when possible.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    name = Keyword.fetch!(opts, :name)
    operator = Keyword.fetch!(opts, :operator)
    identity = Keyword.fetch!(opts, :identity)
    type = Keyword.fetch!(opts, :type)

    %__MODULE__{
      name: name,
      operator: operator,
      identity: identity,
      type: type
    }
  end

  @doc """
  Resolves a monoid name (atom) to its struct, or passes through
  an existing `%Monoid{}` struct.
  """
  @spec resolve(atom() | t()) :: {:ok, t()} | {:error, {:unknown_monoid, atom()}}
  def resolve(%__MODULE__{} = m), do: {:ok, m}

  def resolve(name) when is_atom(name) do
    case builtin(name) do
      nil -> {:error, {:unknown_monoid, name}}
      m -> {:ok, m}
    end
  end

  @doc """
  Returns the built-in monoid struct for the given name, or nil if unknown.
  """
  @spec builtin(atom()) :: t() | nil
  def builtin(:plus), do: new(name: :plus, operator: :plus, identity: 0, type: :int64)
  def builtin(:plus_fp32), do: new(name: :plus_fp32, operator: :plus, identity: 0.0, type: :fp32)
  def builtin(:plus_fp64), do: new(name: :plus_fp64, operator: :plus, identity: 0.0, type: :fp64)
  def builtin(:times), do: new(name: :times, operator: :times, identity: 1, type: :int64)

  def builtin(:times_fp32),
    do: new(name: :times_fp32, operator: :times, identity: 1.0, type: :fp32)

  def builtin(:times_fp64),
    do: new(name: :times_fp64, operator: :times, identity: 1.0, type: :fp64)

  def builtin(:min),
    do:
      new(
        name: :min,
        operator: :min,
        identity: max_int(GraphBLAS.Scalar.new(:int64, 0), :int64),
        type: :int64
      )

  def builtin(:min_fp64),
    do: new(name: :min_fp64, operator: :min, identity: :infinity, type: :fp64)

  def builtin(:max),
    do:
      new(
        name: :max,
        operator: :max,
        identity: min_int(GraphBLAS.Scalar.new(:int64, 0), :int64),
        type: :int64
      )

  def builtin(:max_fp64),
    do: new(name: :max_fp64, operator: :max, identity: :neg_infinity, type: :fp64)

  def builtin(:land), do: new(name: :land, operator: :land, identity: true, type: :bool)
  def builtin(:lor), do: new(name: :lor, operator: :lor, identity: false, type: :bool)
  def builtin(:lxor), do: new(name: :lxor, operator: :lxor, identity: false, type: :bool)
  def builtin(_), do: nil

  defp max_int(_, :int64), do: 9_223_372_036_854_775_807
  defp max_int(_, :int32), do: 2_147_483_647
  defp min_int(_, :int64), do: -9_223_372_036_854_775_808
  defp min_int(_, :int32), do: -2_147_483_648

  @doc """
  Returns the list of all built-in monoid name atoms.
  """
  @spec builtin_names() :: [atom()]
  def builtin_names do
    [
      :plus,
      :plus_fp32,
      :plus_fp64,
      :times,
      :times_fp32,
      :times_fp64,
      :min,
      :min_fp64,
      :max,
      :max_fp64,
      :land,
      :lor,
      :lxor
    ]
  end
end
