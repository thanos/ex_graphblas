defmodule GraphBLAS.ZigStubTest do
  use ExUnit.Case, async: true

  @moduletag :zig_stub

  test "add_one/1 increments an integer" do
    assert GraphBLAS.ZigStub.add_one(41) == 42
  end

  test "ping/0 returns :ok" do
    assert GraphBLAS.ZigStub.ping() == :ok
  end
end
