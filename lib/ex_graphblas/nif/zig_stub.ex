defmodule GraphBLAS.Nif.ZigStub do
  @moduledoc """
  Minimal Zig NIF module for CI verification.

  This module uses `use Zig` directly (no ZiglerPrecompiled, no C libraries)
  to verify that Zigler compiles and loads NIFs correctly on a given
  Elixir/OTP combination.

  It is not a computation backend. Use `GraphBLAS.Backend.ZigStub` which
  wraps this module and implements the `GraphBLAS.Backend` behaviour.
  """

  use Zig,
    otp_app: :ex_graphblas,
    zig_code_path: "../../../priv/native/zig_stub/zig_stub.zig",
    nifs: [:add_one, :ping]
end
