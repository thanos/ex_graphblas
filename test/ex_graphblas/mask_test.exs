defmodule GraphBLAS.MaskTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Backend.Elixir, as: RefBackend
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

  describe "structural mask on matrix_mxm" do
    test "only writes positions present in mask" do
      {:ok, a} =
        RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}, {1, 1, 4}], :int64, [])

      {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      {:ok, c_unmasked} = RefBackend.matrix_mxm(a, b, :plus_times, [])
      {:ok, mask_entries} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      mask = Mask.new(mask_entries)

      {:ok, c_masked} = RefBackend.matrix_mxm(a, b, :plus_times, mask: mask)

      {:ok, coo} = RefBackend.matrix_to_coo(c_masked)
      {:ok, unmasked_coo} = RefBackend.matrix_to_coo(c_unmasked)

      for {r, c, _v} <- coo do
        assert {r, c, 1} in [{0, 0, 1}]
      end

      assert Enum.count(coo) <= Enum.count(unmasked_coo)
    end

    test "complement mask writes positions NOT present in mask" do
      {:ok, a} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 1}], :int64, [])
      {:ok, b} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {1, 1, 1}], :int64, [])
      {:ok, mask_src} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      mask = Mask.complement(mask_src)

      {:ok, c} = RefBackend.matrix_mxm(a, b, :plus_times, mask: mask)
      {:ok, coo} = RefBackend.matrix_to_coo(c)

      for {r, cv, _v} <- coo do
        refute r == 0 and cv == 0
      end
    end
  end

  describe "structural mask on vector operations" do
    test "vector ewise_add with structural vector mask" do
      {:ok, a} = RefBackend.vector_from_entries(3, [{0, 1}, {1, 2}, {2, 3}], :int64, [])
      {:ok, b} = RefBackend.vector_from_entries(3, [{0, 10}, {1, 20}], :int64, [])
      {:ok, mask_src} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      mask = Mask.new(mask_src)

      {:ok, c} = RefBackend.vector_ewise_add(a, b, :plus, mask: mask)
      {:ok, entries} = RefBackend.vector_to_entries(c)

      assert {0, 11} in entries
      refute Enum.any?(entries, fn {i, _v} -> i == 1 end)
      refute Enum.any?(entries, fn {i, _v} -> i == 2 end)
    end

    test "vector ewise_add with complement vector mask" do
      {:ok, a} = RefBackend.vector_from_entries(3, [{0, 1}, {1, 2}], :int64, [])
      {:ok, b} = RefBackend.vector_from_entries(3, [{0, 10}, {1, 20}], :int64, [])
      {:ok, mask_src} = RefBackend.vector_from_entries(3, [{0, 1}], :int64, [])
      mask = Mask.complement(mask_src)

      {:ok, c} = RefBackend.vector_ewise_add(a, b, :plus, mask: mask)
      {:ok, entries} = RefBackend.vector_to_entries(c)

      assert {1, 22} in entries
      refute Enum.any?(entries, fn {i, _v} -> i == 0 end)
    end
  end

  describe "mask on matrix_reduce" do
    test "reduce with structural mask" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}], :int64, [])
      {:ok, mask_src} = RefBackend.vector_from_entries(2, [{0, 1}], :int64, [])
      mask = Mask.new(mask_src)

      {:ok, v} = RefBackend.matrix_reduce(m, :plus, mask: mask)
      {:ok, entries} = RefBackend.vector_to_entries(v)

      assert {0, 3} in entries
      refute Enum.any?(entries, fn {i, _v} -> i == 1 end)
    end
  end

  describe "mask on matrix_transpose" do
    test "transpose with structural mask" do
      {:ok, m} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}, {0, 1, 2}, {1, 0, 3}], :int64, [])
      {:ok, mask_src} = RefBackend.matrix_from_coo(2, 2, [{0, 0, 1}], :int64, [])
      mask = Mask.new(mask_src)

      {:ok, t} = RefBackend.matrix_transpose(m, mask: mask)
      {:ok, coo} = RefBackend.matrix_to_coo(t)

      assert {0, 0, 1} in coo
      refute Enum.any?(coo, fn {r, c, _v} -> r == 0 and c == 1 end)
      refute Enum.any?(coo, fn {r, c, _v} -> r == 1 and c == 0 end)
    end
  end
end
