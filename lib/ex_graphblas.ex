defmodule GraphBLAS do
  @moduledoc """
  GraphBLAS: sparse linear algebra and graph computation for Elixir.

  GraphBLAS is a library for sparse linear algebra and graph computation
  inspired by the GraphBLAS mathematical model. It provides sparse matrices
  and vectors, semirings and monoids for expressing graph algorithms as
  linear algebra, and a backend-neutral API that can delegate computation
  to different execution engines.

  ## Architecture overview

  The library is organized into three layers:

  1. **Public API** -- modules like `GraphBLAS.Matrix`,
     `GraphBLAS.Vector`, `GraphBLAS.Semiring`, and
     `GraphBLAS.Monoid` provide the user-facing interface.

  2. **Backend behaviour** -- `GraphBLAS.Backend` defines the contract
     that every computation backend must implement. Backends are swappable
     at runtime via configuration.

  3. **Backend implementations** -- concrete modules that implement
     `GraphBLAS.Backend`. The `Reference` backend ships with Phase 1
     as a correct-but-not-performant pure Elixir implementation. The
     `SuiteSparse` backend is reserved for Phase 2.

  ## Quick start

      # Create a sparse 3x3 matrix from COO triples
      {:ok, m} = GraphBLAS.Matrix.from_coo(3, 3, [
        {0, 1, 1.0},
        {1, 2, 2.0},
        {2, 0, 3.0}
      ], :fp64)

      # Multiply it by itself using the plus-times semiring
      {:ok, result} = GraphBLAS.Matrix.mxm(m, m, :plus_times)

  ## Backend selection

  The default backend is `GraphBLAS.Backend.Elixir`. To select a
  different backend:

      # Application config
      config :ex_graphblas, default_backend: GraphBLAS.Backend.Elixir

      # Per-call override
      GraphBLAS.Matrix.from_coo(3, 3, entries, :int64, backend: MyBackend)

  ## Phase 1 scope

  Phase 1 establishes the architecture and a reference backend. It does
  not yet include native execution, Nx integration, or graph algorithms.
  See the Phase 1 educational materials for details.
  """

  alias GraphBLAS.Config

  @doc """
  Returns the currently configured default backend module.

  This is a convenience function equivalent to `GraphBLAS.Config.default_backend/0`.
  """
  @spec default_backend() :: module()
  defdelegate default_backend(), to: Config

  @doc """
  Returns information about the library version and configuration.

  Useful for debugging and logging.
  """
  @spec info() :: map()
  def info do
    %{
      version: "0.1.0",
      default_backend: Config.default_backend(),
      phase: 1,
      description: "Architecture, API shape, and scaffolding"
    }
  end
end
