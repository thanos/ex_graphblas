defmodule GraphBLAS.ConfigTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Config

  describe "default_backend/0" do
    test "returns Reference backend by default" do
      assert Config.default_backend() == GraphBLAS.Backend.Elixir
    end
  end

  describe "resolve_backend/1" do
    test "returns configured backend when no option given" do
      assert Config.resolve_backend([]) == GraphBLAS.Backend.Elixir
    end

    test "returns explicit backend when provided" do
      assert Config.resolve_backend(backend: SomeOtherBackend) == SomeOtherBackend
    end

    test "ignores other options" do
      assert Config.resolve_backend(type: :int64, backend: MyBackend) == MyBackend
    end
  end
end
