defmodule GraphBLAS.MonoidTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Monoid

  describe "builtin/1" do
    test "returns monoid struct for known names" do
      for name <- Monoid.builtin_names() do
        assert %Monoid{name: ^name} = Monoid.builtin(name)
      end
    end

    test "returns nil for unknown names" do
      assert nil == Monoid.builtin(:nonexistent)
    end
  end

  describe "resolve/1" do
    test "resolves atom to monoid struct" do
      assert {:ok, %Monoid{name: :plus}} = Monoid.resolve(:plus)
    end

    test "passes through existing monoid struct" do
      m = Monoid.builtin(:plus)
      assert {:ok, ^m} = Monoid.resolve(m)
    end

    test "returns error for unknown atom" do
      assert {:error, {:unknown_monoid, :bad}} = Monoid.resolve(:bad)
    end
  end

  describe "plus monoid" do
    test "has correct structure" do
      m = Monoid.builtin(:plus)
      assert m.operator == :plus
      assert m.identity == 0
      assert m.type == :int64
    end
  end

  describe "times monoid" do
    test "has correct structure" do
      m = Monoid.builtin(:times)
      assert m.operator == :times
      assert m.identity == 1
    end
  end
end
