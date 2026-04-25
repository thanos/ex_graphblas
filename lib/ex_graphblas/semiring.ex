defmodule GraphBLAS.Semiring do
  @moduledoc """
  Semiring definitions for GraphBLAS.

  A **semiring** is the fundamental algebraic structure in GraphBLAS.
  It generalizes ring multiplication and addition to operate on sparse
  data, and it is what makes graph algorithms expressible as linear algebra.

  ## Mathematical definition

  A semiring `(S, ⊗, ⊕, 𝟎, 𝟏)` consists of:

  - A set `S` of values
  - A multiplicative (binary) operator `⊗` with identity `𝟏`
  - An additive (commutative, associative) operator `⊕` with identity `𝟎`
  - The property that `⊗` distributes over `⊕`
  - `𝟎` is an annihilator for `⊗`: `a ⊗ 𝟎 = 𝟎 ⊗ a = 𝟎`

  In GraphBLAS matrix multiplication `C = A ⊗.⊕ B`, the semiring tells us:
  - `⊗` is the "multiplication" applied to matching pairs from A and B
  - `⊕` is the "addition" used to combine the products for each output entry

  ## Built-in semirings

  Phase 1 provides these commonly used semirings:

  | Name        | ⊗ (multiply) | ⊕ (add)  | Use                            |
  |-------------|--------------|-----------|--------------------------------|
  | `:plus_times` | `a * b`      | `a + b`   | Standard matrix multiplication |
  | `:plus_min`   | `min(a, b)`  | `a + b`   | Shortest path algorithms      |
  | `:plus_min2`  | `min(a, b)`  | `min(a, b)`| Minimum-weight path          |
  | `:max_plus`   | `a + b`      | `max(a,b)`| Longest path / critical path   |
  | `:max_min`    | `min(a, b)`  | `max(a,b)`| Reachability with capacity    |
  | `:lor_land`   | `a ∧ b`      | `a ∨ b`   | Boolean adjacency (BFS)       |

  ## Custom semirings

  You can define custom semirings using `%Semiring{}` structs when the
  built-in set does not cover your needs. The `multiply` and `add`
  fields should be atoms naming a `BinaryOp` or functions of arity 2.
  """

  alias GraphBLAS.Types

  @type t :: %__MODULE__{
          name: atom(),
          multiply: atom() | (term(), term() -> term()),
          add: atom() | (term(), term() -> term()),
          add_identity: term(),
          multiply_identity: term(),
          type: Types.scalar_type()
        }

  @enforce_keys [:name, :multiply, :add, :add_identity, :multiply_identity, :type]
  defstruct [:name, :multiply, :add, :add_identity, :multiply_identity, :type]

  @doc """
  Creates a custom semiring struct.

  Prefer using built-in semirings by atom name when possible. Custom
  semirings are for cases where the built-in set does not suffice.

  ## Parameters

  - `:name` -- an atom identifying this semiring
  - `:multiply` -- the ⊗ operator (atom naming a BinaryOp, or a function)
  - `:add` -- the ⊕ operator (atom naming a BinaryOp or Monoid, or a function)
  - `:add_identity` -- the 𝟎 identity element for the add operator
  - `:multiply_identity` -- the 𝟏 identity element for the multiply operator
  - `:type` -- the scalar type this semiring operates on

  Raises `KeyError` if any required key is missing.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    name = Keyword.fetch!(opts, :name)
    multiply = Keyword.fetch!(opts, :multiply)
    add = Keyword.fetch!(opts, :add)
    add_identity = Keyword.fetch!(opts, :add_identity)
    multiply_identity = Keyword.fetch!(opts, :multiply_identity)
    type = Keyword.fetch!(opts, :type)

    %__MODULE__{
      name: name,
      multiply: multiply,
      add: add,
      add_identity: add_identity,
      multiply_identity: multiply_identity,
      type: type
    }
  end

  @doc """
  Resolves a semiring name (atom) to its struct, or passes through
  an existing `%Semiring{}` struct.

  This is the canonical way to normalize a semiring argument from API calls.
  """
  @spec resolve(atom() | t()) :: {:ok, t()} | {:error, {:unknown_semiring, atom()}}
  def resolve(%__MODULE__{} = s), do: {:ok, s}

  def resolve(name) when is_atom(name) do
    case builtin(name) do
      nil -> {:error, {:unknown_semiring, name}}
      s -> {:ok, s}
    end
  end

  @doc """
  Returns the built-in semiring struct for the given name, or nil if unknown.
  """
  @spec builtin(atom()) :: t() | nil
  def builtin(:plus_times),
    do:
      new(
        name: :plus_times,
        multiply: :times,
        add: :plus,
        add_identity: 0,
        multiply_identity: 1,
        type: :int64
      )

  def builtin(:plus_times_fp64),
    do:
      new(
        name: :plus_times_fp64,
        multiply: :times,
        add: :plus,
        add_identity: 0.0,
        multiply_identity: 1.0,
        type: :fp64
      )

  def builtin(:plus_min),
    do:
      new(
        name: :plus_min,
        multiply: :min,
        add: :plus,
        add_identity: 0,
        multiply_identity: nil,
        type: :int64
      )

  def builtin(:plus_min_fp64),
    do:
      new(
        name: :plus_min_fp64,
        multiply: :min,
        add: :plus,
        add_identity: 0.0,
        multiply_identity: nil,
        type: :fp64
      )

  def builtin(:max_plus),
    do:
      new(
        name: :max_plus,
        multiply: :plus,
        add: :max,
        add_identity: nil,
        multiply_identity: 0,
        type: :int64
      )

  def builtin(:max_plus_fp64),
    do:
      new(
        name: :max_plus_fp64,
        multiply: :plus,
        add: :max,
        add_identity: nil,
        multiply_identity: 0.0,
        type: :fp64
      )

  def builtin(:max_min),
    do:
      new(
        name: :max_min,
        multiply: :min,
        add: :max,
        add_identity: nil,
        multiply_identity: nil,
        type: :int64
      )

  def builtin(:max_min_fp64),
    do:
      new(
        name: :max_min_fp64,
        multiply: :min,
        add: :max,
        add_identity: nil,
        multiply_identity: nil,
        type: :fp64
      )

  def builtin(:lor_land),
    do:
      new(
        name: :lor_land,
        multiply: :land,
        add: :lor,
        add_identity: false,
        multiply_identity: true,
        type: :bool
      )

  def builtin(:land_lor),
    do:
      new(
        name: :land_lor,
        multiply: :lor,
        add: :land,
        add_identity: true,
        multiply_identity: false,
        type: :bool
      )

  def builtin(:min_plus),
    do:
      new(
        name: :min_plus,
        multiply: :plus,
        add: :min,
        add_identity: nil,
        multiply_identity: 0,
        type: :int64
      )

  def builtin(:min_plus_fp64),
    do:
      new(
        name: :min_plus_fp64,
        multiply: :plus,
        add: :min,
        add_identity: nil,
        multiply_identity: 0.0,
        type: :fp64
      )

  def builtin(_), do: nil

  @doc """
  Returns the list of all built-in semiring name atoms.
  """
  @spec builtin_names() :: [atom()]
  def builtin_names do
    [
      :plus_times,
      :plus_times_fp64,
      :plus_min,
      :plus_min_fp64,
      :max_plus,
      :max_plus_fp64,
      :max_min,
      :max_min_fp64,
      :lor_land,
      :land_lor,
      :min_plus,
      :min_plus_fp64
    ]
  end
end
