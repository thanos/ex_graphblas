# Run all benchmark suites sequentially.
#
# Usage: mix run bench/run_all.exs

IO.puts("=== Running Parity Benchmarks ===")
Code.require_file("parity_benchmarks.exs", __DIR__)

IO.puts("\n=== Running Core Operations Benchmarks ===")
Code.require_file("core_ops_benchmarks.exs", __DIR__)

IO.puts("\n=== Running Phase 5 Benchmarks ===")
Code.require_file("phase5_benchmarks.exs", __DIR__)

IO.puts("\n=== Running Phase 6 Algorithms Benchmarks ===")
Code.require_file("phase6_algorithms_benchmarks.exs", __DIR__)

IO.puts("\n=== All benchmarks complete ===")
