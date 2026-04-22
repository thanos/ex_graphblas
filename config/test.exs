import Config

config :ex_graphblas,
  default_backend: GraphBLAS.Backend.Elixir

config :zigler_precompiled, :force_build, ex_graphblas: true
