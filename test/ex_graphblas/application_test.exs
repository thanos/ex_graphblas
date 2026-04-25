defmodule GraphBLAS.ApplicationTest do
  use ExUnit.Case, async: false

  describe "start/2" do
    test "starts the application supervisor" do
      assert Process.whereis(GraphBLAS.Supervisor) != nil
    end
  end

  describe "stop/1" do
    test "calls grb_finalize and returns :ok" do
      result = GraphBLAS.Application.stop(:normal)
      assert result == :ok

      case Code.ensure_loaded(GraphBLAS.Native.SuiteSparse) do
        {:module, mod} ->
          try do
            mod.grb_init()
          rescue
            _ -> :ok
          end

        {:error, _} ->
          :ok
      end
    end
  end
end
