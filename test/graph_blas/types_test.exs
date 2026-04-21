defmodule GraphBLAS.TypesTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Types

  describe "validate_scalar_type/1" do
    test "accepts all valid scalar types" do
      for type <- [
            :bool,
            :int8,
            :int16,
            :int32,
            :int64,
            :uint8,
            :uint16,
            :uint32,
            :uint64,
            :fp32,
            :fp64
          ] do
        assert :ok = Types.validate_scalar_type(type)
      end
    end

    test "rejects unknown types" do
      assert {:error, {:unknown_type, :float}} = Types.validate_scalar_type(:float)
      assert {:error, {:unknown_type, :string}} = Types.validate_scalar_type(:string)
      assert {:error, {:unknown_type, 42}} = Types.validate_scalar_type(42)
    end
  end

  describe "infer_type/1" do
    test "infers bool type from boolean values" do
      assert :bool = Types.infer_type([true, false, true])
    end

    test "infers fp64 type from float values" do
      assert :fp64 = Types.infer_type([1.0, 2.5, 3.0])
    end

    test "infers fp64 when mixed ints and floats" do
      assert :fp64 = Types.infer_type([1, 2.5])
    end

    test "infers int64 from integer values" do
      assert :int64 = Types.infer_type([1, 2, 3])
    end

    test "defaults to int64 for empty list" do
      assert :int64 = Types.infer_type([])
    end
  end

  describe "type_size/1" do
    test "returns correct byte sizes" do
      assert 1 = Types.type_size(:bool)
      assert 1 = Types.type_size(:int8)
      assert 2 = Types.type_size(:int16)
      assert 4 = Types.type_size(:int32)
      assert 8 = Types.type_size(:int64)
      assert 1 = Types.type_size(:uint8)
      assert 4 = Types.type_size(:fp32)
      assert 8 = Types.type_size(:fp64)
    end
  end

  describe "default_int_type/0" do
    test "returns :int64" do
      assert :int64 = Types.default_int_type()
    end
  end

  describe "default_fp_type/0" do
    test "returns :fp64" do
      assert :fp64 = Types.default_fp_type()
    end
  end
end
