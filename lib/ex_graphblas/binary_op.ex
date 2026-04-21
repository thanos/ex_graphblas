defmodule GraphBLAS.BinaryOp do
  @moduledoc """
  Binary operator definitions for GraphBLAS.

  Binary operators are the building blocks of semirings and monoids.
  In GraphBLAS, a binary operator is a function `f(a, b) -> c` that
  combines two values. They are used as:

  - The multiplicative operator in a semiring (e.g., `times` in `plus_times`)
  - The additive operator in a semiring (e.g., `plus` in `plus_times`)
  - The operator in a monoid (e.g., `plus` in the additive monoid)
  - Element-wise operations on matrices and vectors

  ## Built-in binary operators

  Phase 1 provides the operators needed by the built-in semirings and
  monoids. These are referenced by atom name throughout the API.
  """

  alias GraphBLAS.Types

  @type t :: %__MODULE__{
          name: atom(),
          function: (term(), term() -> term()),
          type: Types.scalar_type()
        }

  @enforce_keys [:name, :function, :type]
  defstruct [:name, :function, :type]

  @doc """
  Creates a custom binary operator struct.

  Prefer using built-in operators by atom name when possible.
  Custom operators are for cases where the built-in set does not suffice.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    name = Keyword.fetch!(opts, :name)
    function = Keyword.fetch!(opts, :function)
    type = Keyword.fetch!(opts, :type)

    %__MODULE__{name: name, function: function, type: type}
  end

  @doc """
  Applies a binary operator to two values.

  The operator can be an atom naming a built-in, or a `%BinaryOp{}` struct.
  """
  @spec apply(atom() | t(), term(), term()) :: term()
  def apply(%__MODULE__{function: fun}, a, b), do: fun.(a, b)

  def apply(name, a, b) when is_atom(name) do
    fn_for(name).(a, b)
  end

  @doc """
  Returns the function implementation for a built-in binary operator name.
  """
  @spec fn_for(atom()) :: (term(), term() -> term())
  def fn_for(:plus), do: &Kernel.+/2
  def fn_for(:times), do: &Kernel.*/2
  def fn_for(:minus), do: &Kernel.-/2
  def fn_for(:min), do: &min/2
  def fn_for(:max), do: &max/2
  def fn_for(:land), do: &Kernel.and/2
  def fn_for(:lor), do: &Kernel.or/2
  def fn_for(:lxor), do: fn a, b -> a != b end
  def fn_for(name), do: raise(ArgumentError, "Unknown binary operator: #{inspect(name)}")

  @doc """
  Returns the list of all built-in binary operator name atoms.
  """
  @spec builtin_names() :: [atom()]
  def builtin_names do
    [:plus, :times, :minus, :min, :max, :land, :lor, :lxor]
  end
end
