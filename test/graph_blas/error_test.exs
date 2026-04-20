defmodule GraphBLAS.ErrorTest do
  use ExUnit.Case, async: true

  alias GraphBLAS.Error

  describe "new/2" do
    test "creates error with reason only" do
      err = Error.new({:dimension_mismatch, {3, 3}, {2, 4}})
      assert err.reason == {:dimension_mismatch, {3, 3}, {2, 4}}
      assert err.message == nil
      assert err.context == %{}
    end

    test "creates error with reason and message" do
      err = Error.new({:type_mismatch, :int64, :fp64}, message: "types must agree")
      assert err.reason == {:type_mismatch, :int64, :fp64}
      assert err.message == "types must agree"
    end

    test "creates error with reason, message, and context" do
      err =
        Error.new({:backend_error, SomeBackend, :crash},
          message: "native crash",
          context: %{exit_code: 1}
        )

      assert err.context == %{exit_code: 1}
    end
  end

  describe "error/2" do
    test "returns {:error, %Error{}} tuple" do
      assert {:error, %Error{}} = Error.error({:invalid_argument, "bad"})
    end
  end

  describe "format_error/1" do
    test "formats dimension mismatch" do
      err = Error.new({:dimension_mismatch, {3, 3}, {2, 4}})
      msg = Error.format_error(err)
      assert msg =~ "Dimension mismatch"
      assert msg =~ "{3, 3}"
      assert msg =~ "{2, 4}"
    end

    test "formats type mismatch" do
      err = Error.new({:type_mismatch, :int64, :fp64})
      assert Error.format_error(err) =~ "Type mismatch"
    end

    test "formats unsupported type" do
      err = Error.new({:unsupported_type, :bad_type})
      assert Error.format_error(err) =~ "Unsupported scalar type"
    end

    test "formats unsupported operation" do
      err = Error.new({:unsupported_operation, :mxm, SomeBackend})
      assert Error.format_error(err) =~ "Operation :mxm not supported"
    end

    test "formats backend error" do
      err = Error.new({:backend_error, SomeBackend, :segfault})
      assert Error.format_error(err) =~ "Backend error"
    end

    test "formats null handle" do
      err = Error.new({:null_handle, :matrix})
      assert Error.format_error(err) =~ "null or destroyed :matrix handle"
    end

    test "formats index out of bounds" do
      err = Error.new({:index_out_of_bounds, 5, :row, 3})
      assert Error.format_error(err) =~ "Index 5 out of bounds"
    end

    test "formats empty collection" do
      err = Error.new({:empty_collection, :vector})
      assert Error.format_error(err) =~ "Empty collection"
    end

    test "appends message when present" do
      err = Error.new({:dimension_mismatch, {3, 3}, {2, 4}}, message: "during mxm")
      assert Error.format_error(err) =~ "during mxm"
    end

    test "formats unknown reason" do
      err = Error.new(:something_weird)
      assert Error.format_error(err) =~ "Unknown error"
    end
  end

  describe "raise!/2" do
    test "raises ArgumentError with formatted message" do
      assert_raise ArgumentError, ~r/Dimension mismatch/, fn ->
        Error.raise!({:dimension_mismatch, {3, 3}, {2, 4}})
      end
    end
  end
end
