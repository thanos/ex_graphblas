defmodule GraphBLAS.ScalarTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Scalar

  describe "new/2" do
    test "creates integer scalar" do
      s = Scalar.new(:int64, 42)
      assert s.type == :int64
      assert s.value == 42
    end

    test "creates float scalar" do
      s = Scalar.new(:fp64, 3.14)
      assert s.type == :fp64
      assert s.value == 3.14
    end

    test "creates boolean scalar" do
      s = Scalar.new(:bool, true)
      assert s.type == :bool
      assert s.value == true
    end
  end

  describe "value/1" do
    test "extracts the value" do
      assert 42 = Scalar.value(Scalar.new(:int64, 42))
    end
  end

  describe "type/1" do
    test "extracts the type" do
      assert :fp64 = Scalar.type(Scalar.new(:fp64, 1.0))
    end
  end

  describe "zero/2" do
    test "returns additive identity for plus monoid" do
      s = Scalar.zero(:plus, :int64)
      assert s.value == 0
    end

    test "returns multiplicative identity for times monoid" do
      s = Scalar.zero(:times, :int64)
      assert s.value == 1
    end

    test "returns boolean identity for lor monoid" do
      s = Scalar.zero(:lor, :bool)
      assert s.value == false
    end
  end
end
