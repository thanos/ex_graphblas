defmodule GraphBLAS.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    try do
      GraphBLAS.Native.grb_init()
    rescue
      _ -> :ok
    end

    children = []
    opts = [strategy: :one_for_one, name: GraphBLAS.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    GraphBLAS.Native.grb_finalize()
    :ok
  end
end
