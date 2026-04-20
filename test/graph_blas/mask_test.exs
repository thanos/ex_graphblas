defmodule GraphBLAS.MaskTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.{Mask, Matrix}

  describe "new/2" do
    test "creates a structural mask from a matrix" do
      assert {:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 1}], :int64)
      mask = Mask.new(m)
      assert mask.complement == false
      assert mask.source == m
    end

    test "creates a complement mask" do
      assert {:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 1}], :int64)
      mask = Mask.new(m, complement: true)
      assert mask.complement == true
    end
  end

  describe "complement/1" do
    test "creates a complement mask" do
      assert {:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 1}], :int64)
      mask = Mask.complement(m)
      assert Mask.complement?(mask) == true
    end
  end

  describe "complement?/1" do
    test "returns false for structural mask" do
      assert {:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 1}], :int64)
      mask = Mask.new(m)
      assert Mask.complement?(mask) == false
    end
  end

  describe "source/1" do
    test "returns the source container" do
      assert {:ok, m} = Matrix.from_coo(3, 3, [{0, 0, 1}], :int64)
      mask = Mask.new(m)
      assert Mask.source(mask) == m
    end
  end
end
