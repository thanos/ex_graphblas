defmodule GraphBLAS.TopLevelTest do
  use ExUnit.Case, async: true

  alias GraphBLAS

  describe "default_backend/0" do
    test "returns Reference backend" do
      assert GraphBLAS.default_backend() == GraphBLAS.Backend.Elixir
    end
  end

  describe "info/0" do
    test "returns library information" do
      info = GraphBLAS.info()
      assert info.version == "0.1.0"
      assert info.phase == 1
      assert info.default_backend == GraphBLAS.Backend.Elixir
    end
  end
end
