defmodule GraphBLAS.BinaryOpTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.BinaryOp

  describe "fn_for/1" do
    test "returns correct function for each built-in" do
      assert 3 = BinaryOp.fn_for(:plus).(1, 2)
      assert 6 = BinaryOp.fn_for(:times).(2, 3)
      assert 1 = BinaryOp.fn_for(:min).(1, 5)
      assert 5 = BinaryOp.fn_for(:max).(1, 5)
      assert true = BinaryOp.fn_for(:land).(true, true)
      assert true = BinaryOp.fn_for(:lor).(true, false)
    end

    test "raises for unknown operator" do
      assert_raise ArgumentError, ~r/Unknown binary operator/, fn ->
        BinaryOp.fn_for(:nonexistent)
      end
    end
  end

  describe "apply/3" do
    test "applies builtin operator by name" do
      assert 5 = BinaryOp.apply(:plus, 2, 3)
      assert 6 = BinaryOp.apply(:times, 2, 3)
    end

    test "applies custom operator struct" do
      op = BinaryOp.new(name: :double_add, function: fn a, b -> a + b * 2 end, type: :int64)
      assert 7 = BinaryOp.apply(op, 1, 3)
    end
  end

  describe "builtin_names/0" do
    test "returns list of known operators" do
      names = BinaryOp.builtin_names()
      assert :plus in names
      assert :times in names
      assert :min in names
      assert :max in names
    end
  end
end
