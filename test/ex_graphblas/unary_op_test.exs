defmodule GraphBLAS.UnaryOpTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.UnaryOp

  describe "fn_for/1" do
    test "returns correct function for identity" do
      assert 42 = UnaryOp.fn_for(:identity).(42)
    end

    test "returns correct function for negate_int" do
      assert -5 = UnaryOp.fn_for(:negate_int).(5)
    end

    test "returns correct function for negate_fp" do
      assert -2.5 = UnaryOp.fn_for(:negate_fp).(2.5)
    end

    test "returns correct function for abs_val" do
      assert 5 = UnaryOp.fn_for(:abs_val).(-5)
    end

    test "returns correct function for l_not" do
      assert UnaryOp.fn_for(:l_not).(true) == false
      assert UnaryOp.fn_for(:l_not).(false) == true
    end

    test "raises for unknown operator" do
      assert_raise ArgumentError, ~r/Unknown unary operator/, fn ->
        UnaryOp.fn_for(:nonexistent)
      end
    end
  end

  describe "apply/2" do
    test "applies builtin operator by name" do
      assert 5 = UnaryOp.apply(:abs_val, -5)
      assert -3 = UnaryOp.apply(:negate_int, 3)
    end

    test "applies custom operator struct" do
      op = UnaryOp.new(name: :square, function: fn x -> x * x end, type: :int64)
      assert 9 = UnaryOp.apply(op, 3)
    end
  end
end
