defmodule GraphBLAS.Application do
  @moduledoc false

  use Application
  require Logger

  @native_mod GraphBLAS.Native.SuiteSparse

  @impl true
  def start(_type, _args) do
    case Code.ensure_loaded(@native_mod) do
      {:module, mod} ->
        try do
          mod.grb_init()
        rescue
          e -> Logger.debug("SuiteSparse grb_init failed: #{inspect(e)}")
        end

      {:error, _} ->
        :ok
    end

    children = []
    opts = [strategy: :one_for_one, name: GraphBLAS.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    case Code.ensure_loaded(@native_mod) do
      {:module, mod} ->
        try do
          mod.grb_finalize()
        rescue
          e -> Logger.debug("SuiteSparse grb_finalize failed: #{inspect(e)}")
        end

      {:error, _} ->
        :ok
    end

    :ok
  end
end
