defmodule GraphBLAS.DescriptorTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Descriptor

  describe "new/1" do
    test "creates descriptor with defaults" do
      d = Descriptor.new()
      assert d.inp0_transpose == :none
      assert d.inp1_transpose == :none
      assert d.output == :merge
      assert d.mask == :structural
    end

    test "creates descriptor with custom options" do
      d = Descriptor.new(inp0_transpose: :transpose, output: :replace)
      assert d.inp0_transpose == :transpose
      assert d.inp1_transpose == :none
      assert d.output == :replace
    end
  end

  describe "inp0_transpose/0" do
    test "returns descriptor with first input transposed" do
      d = Descriptor.inp0_transpose()
      assert d.inp0_transpose == :transpose
    end
  end

  describe "replace_output/0" do
    test "returns descriptor with replace output mode" do
      d = Descriptor.replace_output()
      assert d.output == :replace
    end
  end
end
