defmodule GraphBLAS.ApplicationTest do
  use ExUnit.Case, async: false

  describe "start/2" do
    test "starts the application supervisor" do
      assert Process.whereis(GraphBLAS.Supervisor) != nil
    end
  end

  describe "stop/1" do
    test "calls grb_finalize and returns :ok" do
      # grb_finalize destroys the SuiteSparse runtime; re-init
      # or subsequent tests will segfault.
      result = GraphBLAS.Application.stop(:normal)
      assert result == :ok

      try do
        GraphBLAS.Native.grb_init()
      rescue
        _ -> :ok
      end
    end
  end
end
