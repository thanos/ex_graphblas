defmodule GraphBLAS.Config do
  @moduledoc """
  Configuration for GraphBLAS backend selection and defaults.

  GraphBLAS supports multiple backends. The active backend is determined
  in this order:

  1. Explicit `:backend` option passed to an individual function call.
  2. Application configuration (`config :ex_graphblas, :default_backend`).
  3. The compiled-in default: `GraphBLAS.Backend.Elixir`.

  This module provides runtime access to configuration so that backend
  modules can remain decoupled from the application environment.

  ## Example configuration

  In `config/config.exs`:

      config :ex_graphblas,
        default_backend: GraphBLAS.Backend.Elixir

  Or at runtime:

      Application.put_env(:ex_graphblas, :default_backend, MyCustomBackend)
  """

  @default_backend GraphBLAS.Backend.Elixir

  @doc """
  Returns the currently configured default backend module.

  The default backend is used when no `:backend` option is provided
  to an individual API call. It can be configured via application
  environment or defaults to `GraphBLAS.Backend.Elixir`.
  """
  @spec default_backend() :: module()
  def default_backend do
    Application.get_env(:ex_graphblas, :default_backend, @default_backend)
  end

  @doc """
  Resolves the effective backend for an operation.

  Takes an optional keyword list and extracts the `:backend` key if present.
  Falls back to the configured default backend if absent.

  ## Examples

      iex> GraphBLAS.Config.resolve_backend([])
      GraphBLAS.Backend.Elixir

      iex> GraphBLAS.Config.resolve_backend(backend: MyBackend)
      MyBackend
  """
  @spec resolve_backend(keyword()) :: module()
  def resolve_backend(opts) when is_list(opts) do
    Keyword.get(opts, :backend, default_backend())
  end

  @doc """
  Returns the default scalar type for integer containers.

  This is `:int64` by default, matching the GraphBLAS convention.
  Can be overridden via application configuration.
  """
  @spec default_int_type() :: GraphBLAS.Types.scalar_type()
  def default_int_type do
    Application.get_env(:ex_graphblas, :default_int_type, :int64)
  end

  @doc """
  Returns the default scalar type for floating-point containers.

  This is `:fp64` by default, matching the GraphBLAS convention.
  Can be overridden via application configuration.
  """
  @spec default_fp_type() :: GraphBLAS.Types.scalar_type()
  def default_fp_type do
    Application.get_env(:ex_graphblas, :default_fp_type, :fp64)
  end
end
