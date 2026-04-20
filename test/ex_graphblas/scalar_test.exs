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

    test "returns boolean identity for land monoid" do
      s = Scalar.zero(:land, :bool)
      assert s.value == true
    end

    test "returns max value for min monoid with int64" do
      s = Scalar.zero(:min, :int64)
      assert s.value == 9_223_372_036_854_775_807
    end

    test "returns min value for max monoid with int64" do
      s = Scalar.zero(:max, :int64)
      assert s.value == -9_223_372_036_854_775_808
    end

    test "returns additive identity for plus monoid with fp64" do
      s = Scalar.zero(:plus, :fp64)
      assert s.value == 0.0
    end

    test "returns multiplicative identity for times monoid with fp64" do
      s = Scalar.zero(:times, :fp64)
      assert s.value == 1.0
    end

    test "returns max value for min monoid with fp64" do
      s = Scalar.zero(:min, :fp64)
      assert is_float(s.value)
      assert s.value > 0
    end

    test "returns min value for max monoid with fp64" do
      s = Scalar.zero(:max, :fp64)
      assert is_float(s.value)
      assert s.value < 0
    end

    test "returns type max for min monoid with smaller int types" do
      assert Scalar.zero(:min, :int8).value == 127
      assert Scalar.zero(:min, :int16).value == 32_767
      assert Scalar.zero(:min, :int32).value == 2_147_483_647
    end

    test "returns type min for max monoid with smaller int types" do
      assert Scalar.zero(:max, :int8).value == -128
      assert Scalar.zero(:max, :int16).value == -32_768
      assert Scalar.zero(:max, :int32).value == -2_147_483_648
    end

    test "returns type max for min monoid with unsigned types" do
      assert Scalar.zero(:min, :uint8).value == 255
      assert Scalar.zero(:min, :uint16).value == 65_535
      assert Scalar.zero(:min, :uint32).value == 4_294_967_295
      assert Scalar.zero(:min, :uint64).value == 18_446_744_073_709_551_615
    end

    test "returns type min for max monoid with unsigned types" do
      assert Scalar.zero(:max, :uint8).value == 0
      assert Scalar.zero(:max, :uint16).value == 0
      assert Scalar.zero(:max, :uint32).value == 0
      assert Scalar.zero(:max, :uint64).value == 0
    end

    test "returns boolean identities for bool type" do
      assert Scalar.zero(:plus, :bool).value == false
      assert Scalar.zero(:times, :bool).value == true
      assert Scalar.zero(:min, :bool).value == true
      assert Scalar.zero(:max, :bool).value == false
    end

    test "returns fp32 identities" do
      assert Scalar.zero(:plus, :fp32).value == 0.0
      assert Scalar.zero(:times, :fp32).value == 1.0
      assert is_float(Scalar.zero(:min, :fp32).value)
      assert is_float(Scalar.zero(:max, :fp32).value)
    end
  end
end
