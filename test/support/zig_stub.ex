defmodule GraphBLAS.ZigStub do
  @moduledoc false

  use Zig,
    otp_app: :ex_graphblas,
    zig_code_path: "zig_stub.zig",
    nifs: [
      add_one: 1,
      ping: 0
    ]
end
