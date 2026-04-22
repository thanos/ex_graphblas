defmodule GraphBLAS.Relation do
  @moduledoc """
  Knowledge graph and multi-relation model for GraphBLAS.

  A `Relation` wraps a map of predicate names to adjacency matrices,
  all sharing the same entity space size. This models RDF-style
  (subject, predicate, object) triples as predicate-specific
  sparse matrices.

  ## Core concept

  Each predicate maps to its own adjacency matrix:

      A_pred[i][j] = 1  if triple (entity_i, pred, entity_j) exists

  Multi-hop traversal is expressed as chained `mxm`:

      "X follows Y AND Y likes Z" = A_follows mxm A_likes

  The semiring determines query semantics: `:lor_land` for existence,
  `:plus_times` for path counting, `:plus_min` for shortest path.
  """

  alias GraphBLAS.Backend.Elixir, as: RefBackend
  alias GraphBLAS.Backend.SuiteSparse
  alias GraphBLAS.{Config, Error, Matrix}

  @type t :: %__MODULE__{
          size: non_neg_integer(),
          predicates: %{atom() => Matrix.t()}
        }

  @enforce_keys [:size]
  defstruct [:size, predicates: %{}]

  @doc """
  Creates an empty relation with the given entity space size.
  """
  @spec new(non_neg_integer()) :: t()
  def new(size) do
    %__MODULE__{size: size, predicates: %{}}
  end

  @doc """
  Adds (subject, object) pairs for a predicate as bool entries.

  Creates or extends the adjacency matrix for the given predicate.
  Each pair `{s, o}` sets `A_pred[s][o] = true`.
  """
  @spec add_triples(t(), atom(), [{non_neg_integer(), non_neg_integer()}]) ::
          {:ok, t()} | {:error, Error.t()}
  def add_triples(%__MODULE__{size: n, predicates: preds} = rel, predicate, pairs) do
    opts = [backend: Config.default_backend()]
    entries = Enum.map(pairs, fn {s, o} -> {s, o, true} end)

    case Map.fetch(preds, predicate) do
      {:ok, existing} ->
        with {:ok, new_entries} <- ok(Matrix.to_coo(existing)),
             combined <- new_entries ++ entries,
             {:ok, updated} <- Matrix.from_coo(n, n, combined, :bool, opts) do
          {:ok, %{rel | predicates: Map.put(preds, predicate, updated)}}
        end

      :error ->
        case Matrix.from_coo(n, n, entries, :bool, opts) do
          {:ok, mat} -> {:ok, %{rel | predicates: Map.put(preds, predicate, mat)}}
          {:error, _} = err -> err
        end
    end
  end

  @doc """
  Adds weighted (subject, object, value) triples for a predicate.

  Creates or extends the adjacency matrix with the given scalar type.
  """
  @spec add_weighted_triples(
          t(),
          atom(),
          [{non_neg_integer(), non_neg_integer(), number()}],
          atom()
        ) ::
          {:ok, t()} | {:error, Error.t()}
  def add_weighted_triples(
        %__MODULE__{size: n, predicates: preds} = rel,
        predicate,
        triples,
        type
      ) do
    opts = [backend: Config.default_backend()]

    case Map.fetch(preds, predicate) do
      {:ok, existing} ->
        with {:ok, new_entries} <- ok(Matrix.to_coo(existing)),
             combined <- new_entries ++ triples,
             {:ok, updated} <- Matrix.from_coo(n, n, combined, type, opts) do
          {:ok, %{rel | predicates: Map.put(preds, predicate, updated)}}
        end

      :error ->
        case Matrix.from_coo(n, n, triples, type, opts) do
          {:ok, mat} -> {:ok, %{rel | predicates: Map.put(preds, predicate, mat)}}
          {:error, _} = err -> err
        end
    end
  end

  @doc """
  Returns the list of predicate names in this relation.
  """
  @spec predicates(t()) :: [atom()]
  def predicates(%__MODULE__{predicates: preds}) do
    Map.keys(preds)
  end

  @doc """
  Returns the adjacency matrix for a predicate.

  Returns `{:error, {:unknown_predicate, name}}` if the predicate
  does not exist in this relation.
  """
  @spec matrix(t(), atom()) :: {:ok, Matrix.t()} | {:error, Error.t()}
  def matrix(%__MODULE__{predicates: preds}, predicate) do
    case Map.fetch(preds, predicate) do
      {:ok, mat} -> {:ok, mat}
      :error -> Error.error({:unknown_predicate, predicate})
    end
  end

  @doc """
  Multi-hop traversal across predicates via chained mxm.

  `predicate_path` is an ordered list of predicates. The traversal
  chains their adjacency matrices: `A_p1 mxm A_p2 mxm ... mxm A_pk`.

  The semiring determines query semantics:
  - `:lor_land` -- does a path exist? (boolean reachability)
  - `:plus_times` -- how many paths exist? (path counting)
  - `:plus_min` -- shortest path distance
  - `:max_min` -- widest path / bottleneck capacity
  """
  @spec traverse(t(), [atom()], atom() | GraphBLAS.Semiring.t(), keyword()) ::
          {:ok, Matrix.t()} | {:error, Error.t()}
  def traverse(rel, predicate_path, semiring, opts \\ [])

  def traverse(_rel, [], _semiring, _opts), do: Error.error({:empty_predicate_path})

  def traverse(%__MODULE__{} = rel, [p], semiring, opts) do
    with {:ok, mat} <- matrix(rel, p) do
      traverse_single(mat, semiring, opts)
    end
  end

  def traverse(%__MODULE__{} = rel, [p | rest], semiring, opts) do
    with {:ok, first} <- matrix(rel, p),
         {:ok, rest_mats} <- collect_path_mats(rel, rest) do
      needs_int =
        semiring in [
          :plus_times,
          :plus_times_fp64,
          :plus_min,
          :plus_min_fp64,
          :max_plus,
          :max_plus_fp64,
          :min_plus,
          :min_plus_fp64
        ]

      traverse_chain([first | rest_mats], semiring, opts, needs_int)
    end
  end

  defp traverse_single(mat, semiring, opts) do
    backend = Config.resolve_backend(opts)

    case semiring do
      :lor_land ->
        {:ok, mat}

      _ ->
        {:ok, coo} = ok(Matrix.to_coo(mat))

        case coo do
          [] -> Matrix.new(elem(mat.shape, 0), elem(mat.shape, 1), :int64, backend: backend)
          _ -> {:ok, mat}
        end
    end
  end

  defp collect_path_mats(rel, predicates) do
    Enum.reduce_while(predicates, {:ok, []}, fn p, {:ok, acc} ->
      case matrix(rel, p) do
        {:ok, mat} -> {:cont, {:ok, acc ++ [mat]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp traverse_chain([acc], _semiring, _opts, _needs_int), do: {:ok, acc}

  defp traverse_chain([a, b | rest], semiring, opts, needs_int) do
    backend = Config.resolve_backend(opts)

    with {:ok, a_mx} <- maybe_to_int64(a, needs_int, backend),
         {:ok, b_mx} <- maybe_to_int64(b, needs_int, backend),
         {:ok, result} <- ok(Matrix.mxm(a_mx, b_mx, semiring, backend: backend)) do
      cleanup_intermediates(a, b, a_mx, b_mx, backend)
      traverse_chain([result | rest], semiring, opts, needs_int)
    end
  end

  defp cleanup_intermediates(a, b, a_mx, b_mx, backend) do
    maybe_free_intermediate(a, backend)
    maybe_free_intermediate(b, backend)
    if a_mx != a, do: maybe_free_intermediate(a_mx, backend)
    if b_mx != b, do: maybe_free_intermediate(b_mx, backend)
  end

  defp maybe_to_int64(%Matrix{type: :bool} = m, true, backend) do
    with {:ok, coo} <- ok(Matrix.to_coo(m)) do
      int_coo = Enum.map(coo, fn {r, c, true} -> {r, c, 1} end)
      {nrows, ncols} = m.shape
      Matrix.from_coo(nrows, ncols, int_coo, :int64, backend: backend)
    end
  end

  defp maybe_to_int64(%Matrix{} = m, _needs_int, _backend), do: {:ok, m}

  @doc """
  Transitive closure of a single predicate.

  Computes `I + A + A^2 + A^3 + ...` until convergence using
  the `fixed_point` primitive.

  The semiring determines closure semantics:
  - `:lor_land` -- reachability closure (who can eventually reach whom?)
  - `:plus_min` -- shortest path closure
  - `:plus_times` -- all-paths counting closure
  """
  @spec closure(t(), atom(), atom() | GraphBLAS.Semiring.t(), keyword()) ::
          {:ok, Matrix.t()} | {:error, Error.t()}
  def closure(%__MODULE__{predicates: preds} = _rel, predicate, semiring, opts \\ []) do
    case Map.fetch(preds, predicate) do
      {:ok, matrix} ->
        backend = Config.resolve_backend(opts)

        with {:ok, sr} <- GraphBLAS.Semiring.resolve(semiring) do
          closure_loop(matrix, matrix, sr, backend, 0)
        end

      :error ->
        Error.error({:unknown_predicate, predicate})
    end
  end

  defp closure_loop(_a, p, _semiring, _backend, iter) when iter >= 100, do: {:ok, p}

  defp closure_loop(a, p, semiring, backend, iter) do
    add_monoid = semiring.add

    with {:ok, new_paths} <- Matrix.mxm(p, a, semiring.name, backend: backend),
         {:ok, p_new} <- Matrix.ewise_add(p, new_paths, add_monoid, backend: backend),
         {:ok, old_coo} <- Matrix.to_coo(p),
         {:ok, new_coo} <- Matrix.to_coo(p_new) do
      maybe_free_intermediate(new_paths, backend)

      if Enum.sort(old_coo) == Enum.sort(new_coo) do
        maybe_free_intermediate(p, backend)
        {:ok, p_new}
      else
        maybe_free_intermediate(p, backend)
        closure_loop(a, p_new, semiring, backend, iter + 1)
      end
    end
  end

  defp ok({:ok, val}), do: {:ok, val}
  defp ok(%Matrix{} = m), do: {:ok, m}
  defp ok({:error, _} = err), do: err
  defp ok(:ok), do: :ok

  defp maybe_free_intermediate(_mat, RefBackend), do: :ok

  defp maybe_free_intermediate(%Matrix{} = m, SuiteSparse) do
    SuiteSparse.matrix_free(m)
  end

  defp maybe_free_intermediate(_, _), do: :ok
end
