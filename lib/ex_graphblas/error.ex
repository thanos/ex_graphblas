defmodule GraphBLAS.Error do
  @moduledoc """
  Error types for GraphBLAS.

  All errors returned by GraphBLAS are structured using the types
  defined in this module. Errors are returned as `{:error, reason}`
  tuples rather than raised as exceptions, following Elixir convention
  for library code. Exceptions are reserved for programming errors
  (invalid arguments, type mismatches) that indicate bugs in calling code.

  ## Error categories

  - **Dimension errors** -- shape mismatches between operands (e.g.,
    multiplying matrices with incompatible inner dimensions).
  - **Type errors** -- scalar type mismatches or unsupported type
    combinations for a given operation.
  - **Backend errors** -- failures originating in the native layer
    (allocation failures, null handles, native crashes). These are
    wrapped to preserve stack traces and backend context.
  - **Invalid argument errors** -- programming errors such as negative
    indices, empty required arguments, or invalid option keys.

  ## Design note

  GraphBLAS uses structured error reasons rather than atoms or strings.
  This enables pattern matching on specific failure modes without
  string parsing. Each reason is a tuple where the first element identifies
  the error category and subsequent elements provide context.
  """

  @type t :: %__MODULE__{
          reason: reason(),
          message: String.t() | nil,
          context: map()
        }

  @enforce_keys [:reason]
  defstruct [:reason, :message, :context]

  @typedoc """
  A structured error reason.

  Each reason is a tuple where:
  - The first element is the error category atom.
  - Subsequent elements provide category-specific context.

  ## Categories

  - `{:dimension_mismatch, expected, actual}` -- shape mismatch
  - `{:type_mismatch, expected_type, actual_type}` -- scalar type mismatch
  - `{:unsupported_type, type}` -- type not supported by this operation/backend
  - `{:unsupported_operation, operation, backend}` -- operation not available
  - `{:backend_error, backend, detail}` -- native/backend failure
  - `{:null_handle, handle_type}` -- operation on destroyed or uninitialized handle
  - `{:invalid_argument, detail}` -- invalid input to an API call
  - `{:index_out_of_bounds, index, dimension, size}` -- index exceeds dimension
  - `{:mask_type_mismatch, actual, expected}` -- mask container type mismatch
  - `{:unknown_predicate, name}` -- predicate not found in relation
  - `{:empty_predicate_path}` -- traverse called with empty path
  - `{:empty_collection, detail}` -- operation requiring data on empty container
  """
  @type reason ::
          {:dimension_mismatch, term(), term()}
          | {:type_mismatch, term(), term()}
          | {:unsupported_type, term()}
          | {:unsupported_operation, atom(), module()}
          | {:unsupported_operation, module()}
          | {:backend_error, module(), term()}
          | {:null_handle, atom()}
          | {:invalid_argument, term()}
          | {:index_out_of_bounds, non_neg_integer(), atom(), non_neg_integer()}
          | {:mask_type_mismatch, atom(), atom()}
          | {:unknown_predicate, atom()}
          | {:empty_predicate_path}
          | {:empty_collection, term()}

  @doc """
  Creates a new structured error.

  ## Examples

      iex> GraphBLAS.Error.new({:dimension_mismatch, {3, 3}, {2, 4}})
      %GraphBLAS.Error{reason: {:dimension_mismatch, {3, 3}, {2, 4}}, message: nil, context: %{}}

      iex> GraphBLAS.Error.new({:type_mismatch, :int64, :fp64}, message: "operand types must agree")
      %GraphBLAS.Error{reason: {:type_mismatch, :int64, :fp64}, message: "operand types must agree", context: %{}}
  """
  @spec new(reason(), keyword()) :: t()
  def new(reason, opts \\ []) do
    %__MODULE__{
      reason: reason,
      message: Keyword.get(opts, :message),
      context: Keyword.get(opts, :context, %{})
    }
  end

  @doc """
  Wraps an error into an `{:error, t}` tuple.

  This is the primary way to return errors from GraphBLAS operations.

  ## Examples

      iex> GraphBLAS.Error.error({:dimension_mismatch, {3, 3}, {2, 4}})
      {:error, %GraphBLAS.Error{reason: {:dimension_mismatch, {3, 3}, {2, 4}}, message: nil, context: %{}}}
  """
  @spec error(reason(), keyword()) :: {:error, t()}
  def error(reason, opts \\ []) do
    {:error, new(reason, opts)}
  end

  @doc """
  Raises an `ArgumentError` for programming errors that indicate bugs
  in calling code.

  Use this for invalid arguments, type errors, and other conditions that
  should not occur in correct usage. For expected failure modes (e.g.,
  backend errors after retrying), return `{:error, t}` instead.
  """
  @dialyzer {:nowarn_function, raise!: 1}
  @spec raise!(reason(), keyword()) :: no_return()
  def raise!(reason, opts \\ []) do
    err = new(reason, opts)
    raise ArgumentError, format_error(err)
  end

  @doc """
  Formats an error into a human-readable string.

  This is used for log messages and exception messages, not for pattern
  matching. Prefer pattern matching on `reason` directly in calling code.
  """
  @spec format_error(t()) :: String.t()
  def format_error(%__MODULE__{reason: reason, message: msg}) do
    base = format_reason(reason)
    if msg, do: "#{base}: #{msg}", else: base
  end

  defp format_reason({:dimension_mismatch, expected, actual}) do
    "Dimension mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"
  end

  defp format_reason({:type_mismatch, expected, actual}) do
    "Type mismatch: expected #{inspect(expected)}, got #{inspect(actual)}"
  end

  defp format_reason({:unsupported_type, type}) do
    "Unsupported scalar type: #{inspect(type)}"
  end

  defp format_reason({:unsupported_operation, op, backend}) do
    "Operation #{inspect(op)} not supported by backend #{inspect(backend)}"
  end

  defp format_reason({:unsupported_operation, backend}) do
    "Operation not supported by backend #{inspect(backend)}"
  end

  defp format_reason({:backend_error, backend, detail}) do
    "Backend error in #{inspect(backend)}: #{inspect(detail)}"
  end

  defp format_reason({:null_handle, handle_type}) do
    "Operation on null or destroyed #{inspect(handle_type)} handle"
  end

  defp format_reason({:invalid_argument, detail}) do
    "Invalid argument: #{inspect(detail)}"
  end

  defp format_reason({:index_out_of_bounds, idx, dimension, size}) do
    "Index #{idx} out of bounds for #{dimension} of size #{size}"
  end

  defp format_reason({:empty_collection, detail}) do
    "Empty collection: #{inspect(detail)}"
  end

  defp format_reason({:mask_type_mismatch, actual, expected}) do
    "Mask type mismatch: got #{inspect(actual)}, expected #{inspect(expected)}"
  end

  defp format_reason({:unknown_predicate, name}) do
    "Unknown predicate: #{inspect(name)}"
  end

  defp format_reason({:empty_predicate_path}) do
    "Empty predicate path: at least one predicate required"
  end

  defp format_reason(reason) do
    "Unknown error: #{inspect(reason)}"
  end
end
