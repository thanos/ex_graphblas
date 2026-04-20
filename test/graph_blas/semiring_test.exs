defmodule GraphBLAS.SemiringTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Semiring

  describe "builtin/1" do
    test "returns semiring struct for known names" do
      for name <- Semiring.builtin_names() do
        assert %Semiring{name: ^name} = Semiring.builtin(name)
      end
    end

    test "returns nil for unknown names" do
      assert nil == Semiring.builtin(:nonexistent)
    end
  end

  describe "resolve/1" do
    test "resolves atom to semiring struct" do
      assert {:ok, %Semiring{name: :plus_times}} = Semiring.resolve(:plus_times)
    end

    test "passes through existing semiring struct" do
      s = Semiring.builtin(:plus_times)
      assert {:ok, ^s} = Semiring.resolve(s)
    end

    test "returns error for unknown atom" do
      assert {:error, {:unknown_semiring, :bad}} = Semiring.resolve(:bad)
    end
  end

  describe "plus_times semiring" do
    test "has correct structure" do
      s = Semiring.builtin(:plus_times)
      assert s.multiply == :times
      assert s.add == :plus
      assert s.add_identity == 0
      assert s.multiply_identity == 1
    end
  end

  describe "lor_land semiring" do
    test "has correct structure for boolean adjacency" do
      s = Semiring.builtin(:lor_land)
      assert s.multiply == :land
      assert s.add == :lor
      assert s.add_identity == false
      assert s.multiply_identity == true
      assert s.type == :bool
    end
  end
end
