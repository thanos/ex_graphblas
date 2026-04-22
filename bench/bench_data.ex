defmodule GraphBLAS.BenchData do
  @moduledoc false

  def chain_graph(n) do
    Enum.map(0..(n - 2), fn i -> {i, i + 1, true} end)
  end

  def cycle_graph(n) do
    Enum.map(0..(n - 1), fn i -> {i, rem(i + 1, n), true} end)
  end

  def star_graph(n) do
    Enum.map(1..(n - 1), fn i -> {0, i, true} end)
  end

  defp random_pairs(n) do
    rows = Enum.to_list(0..(n - 1))

    Enum.flat_map(rows, fn r ->
      cols = Enum.to_list(0..(n - 1))
      Enum.map(cols, fn c -> {r, c} end)
    end)
  end

  def random_graph(n, density) do
    pairs = random_pairs(n)
    filtered = Enum.filter(pairs, fn _ -> :rand.uniform() < density end)
    entries = Enum.map(filtered, fn {r, c} -> {r, c, true} end)

    fallback = [{0, 1, true}]

    result =
      if entries == [] do
        fallback
      else
        entries
      end

    result
  end

  def weighted_random_graph(n, density) do
    pairs = random_pairs(n)
    filtered = Enum.filter(pairs, fn _ -> :rand.uniform() < density end)
    entries = Enum.map(filtered, fn {r, c} -> {r, c, :rand.uniform() * 10.0} end)

    fallback = [{0, 1, 1.0}]

    result =
      if entries == [] do
        fallback
      else
        entries
      end

    result
  end

  def undirected_random_graph(n, density) do
    rows = Enum.to_list(0..(n - 1))

    upper =
      Enum.flat_map(rows, fn r ->
        cols = Enum.to_list((r + 1)..(n - 1)//1)
        Enum.map(cols, fn c -> {r, c} end)
      end)

    filtered = Enum.filter(upper, fn _ -> :rand.uniform() < density end)
    edges = Enum.map(filtered, fn {r, c} -> {r, c, true} end)

    fallback = [{0, 1, true}]

    final =
      if edges == [] do
        fallback
      else
        edges
      end

    reverse = Enum.map(final, fn {r, c, v} -> {c, r, v} end)
    final ++ reverse
  end
end
