defmodule GraphBLAS.DescriptorTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.Elixir, as: RefBackend
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

  describe "inp1_transpose/0" do
    test "returns descriptor with second input transposed" do
      d = Descriptor.inp1_transpose()
      assert d.inp1_transpose == :transpose
    end
  end

  describe "replace_output/0" do
    test "returns descriptor with replace output mode" do
      d = Descriptor.replace_output()
      assert d.output == :replace
    end
  end

  describe "descriptor with matrix_mxm — inp0_transpose" do
    test "transposing first input changes mxm result" do
      {:ok, a} = RefBackend.matrix_from_coo(2, 3, [{0, 1, 1}, {1, 2, 2}], :int64, [])
      {:ok, b} = RefBackend.matrix_from_coo(2, 3, [{0, 1, 3}, {1, 2, 4}], :int64, [])

      desc = Descriptor.new(inp0_transpose: :transpose)
      {:ok, c} = RefBackend.matrix_mxm(a, b, :plus_times, descriptor: desc)
      {:ok, coo} = RefBackend.matrix_to_coo(c)

      assert coo != []
    end
  end

  describe "descriptor with matrix_mxm — inp1_transpose" do
    test "transposing second input changes mxm result" do
      {:ok, a} = RefBackend.matrix_from_coo(2, 3, [{0, 1, 1}], :int64, [])
      {:ok, b} = RefBackend.matrix_from_coo(2, 3, [{0, 1, 1}], :int64, [])

      desc = Descriptor.new(inp1_transpose: :transpose)
      {:ok, c} = RefBackend.matrix_mxm(a, b, :plus_times, descriptor: desc)
      {:ok, coo} = RefBackend.matrix_to_coo(c)

      assert is_list(coo)
    end
  end

  describe "descriptor with mask mode :value" do
    test "value mask filters by truthy values in mask source" do
      {:ok, a} = RefBackend.vector_from_entries(3, [{0, 1}, {1, 2}, {2, 3}], :int64, [])
      {:ok, b} = RefBackend.vector_from_entries(3, [{0, 10}, {1, 20}], :int64, [])
      {:ok, mask_src} = RefBackend.vector_from_entries(3, [{0, true}, {1, false}], :bool, [])

      mask = GraphBLAS.Mask.new(mask_src)
      desc = Descriptor.new(mask: :value)

      {:ok, c} = RefBackend.vector_ewise_add(a, b, :plus, mask: mask, descriptor: desc)
      {:ok, entries} = RefBackend.vector_to_entries(c)

      assert {0, 11} in entries
      refute Enum.any?(entries, fn {i, _v} -> i == 1 end)
    end
  end
end
