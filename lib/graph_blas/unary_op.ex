defmodule GraphBLAS.UnaryOp do
  @moduledoc """
  Unary operator definitions for GraphBLAS.

  Unary operators apply a function to a single value: `f(a) -> b`.
  They are used for element-wise transformations on matrices and vectors,
  such as negation, absolute value, or logical complement.

  Phase 1 provides a minimal set of unary operators. The primary use case
  is descriptor-controlled operations where a transform is applied to
  an input before the main computation (e.g., complementing a mask).

  ## Built-in unary operators

  | Name     | Function | Description           |
  |----------|----------|-----------------------|
  | `:identity` | `fn x -> x end` | No-op passthrough |
  | `:negate`   | `fn x -> -x end` | Arithmetic negation |
  | `:abs_val`  | `fn x -> abs(x) end` | Absolute value |
  | `:l_not`    | `fn x -> not x end` | Logical complement |

  These are placeholders for the full set needed in later phases.
  The Reference backend implements all listed operators.
  """

  alias GraphBLAS.Types

  @type t :: %__MODULE__{
          name: atom(),
          function: (term() -> term()),
          type: Types.scalar_type()
        }

  @enforce_keys [:name, :function, :type]
  defstruct [:name, :function, :type]

  @doc """
  Creates a custom unary operator struct.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    name = Keyword.fetch!(opts, :name)
    function = Keyword.fetch!(opts, :function)
    type = Keyword.fetch!(opts, :type)

    %__MODULE__{name: name, function: function, type: type}
  end

  @doc """
  Applies a unary operator to a value.
  """
  @spec apply(atom() | t(), term()) :: term()
  def apply(%__MODULE__{function: fun}, a), do: fun.(a)

  def apply(name, a) when is_atom(name) do
    fn_for(name).(a)
  end

  @doc """
  Returns the function implementation for a built-in unary operator name.
  """
  @spec fn_for(atom()) :: (term() -> term())
  def fn_for(:identity), do: &Function.identity/1
  def fn_for(:negate_int), do: fn x -> -x end
  def fn_for(:negate_fp), do: fn x -> -x * 1.0 end
  def fn_for(:abs_val), do: &abs/1
  def fn_for(:l_not), do: &Kernel.not/1
  def fn_for(name), do: raise(ArgumentError, "Unknown unary operator: #{inspect(name)}")

  @doc """
  Returns the list of all built-in unary operator name atoms.
  """
  @spec builtin_names() :: [atom()]
  def builtin_names, do: [:identity, :negate_int, :negate_fp, :abs_val, :l_not]
end
