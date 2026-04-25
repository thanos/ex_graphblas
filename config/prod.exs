import Config

# The default backend is pure Elixir -- no native dependencies required.
# To use the SuiteSparse native backend in production, set:
#
#   config :ex_graphblas, default_backend: GraphBLAS.Backend.SuiteSparse
#
# and ensure SuiteSparse:GraphBLAS >= 9.4.5 is installed. See the
# installation guide for platform-specific instructions.
config :ex_graphblas,
  default_backend: GraphBLAS.Backend.Elixir
