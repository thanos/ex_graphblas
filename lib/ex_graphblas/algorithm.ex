defmodule GraphBLAS.Algorithm do
  @moduledoc """
  Graph algorithms built on the GraphBLAS sparse linear algebra primitives.

  All algorithms are backend-agnostic: they call the public `Matrix`/`Vector`
  API and work on both the Elixir reference backend and the SuiteSparse native
  backend. No new backend callbacks are needed.

  ## Adjacency matrix convention

  All algorithms assume `A[i][j]` means edge FROM vertex i TO vertex j.

  - Row i contains the OUT-neighbors of vertex i
  - Column j contains the IN-neighbors of vertex j
  - For undirected graphs, A is symmetric (A = A^T)

  ## Families

  - **Phase 6A** -- Classic graph analytics (BFS, SSSP, triangle count, etc.)
  - **Phase 6C** -- Query foundations (fixed-point iteration primitive)
  """

  alias GraphBLAS.{Config, Descriptor, Error, Helpers, Mask, Matrix, Scalar, Vector}

  import Helpers, only: [ok: 1, maybe_free: 2]

  @default_max_iter 100
  @default_tol 1.0e-6
  @sssp_inf 1.0e18

  # ---------------------------------------------------------------------------
  # Phase 6A: Classic Graph Analytics
  # ---------------------------------------------------------------------------

  @doc """
  BFS reachability from a source vertex.

  Returns a bool vector where `visited[i] = true` iff vertex i is reachable
  from the source vertex.

  Uses the `:lor_land` semiring with a complement mask to prevent revisiting.
  Converges when the frontier is empty.
  """
  @spec bfs_reach(Matrix.t(), non_neg_integer(), keyword()) ::
          {:ok, Vector.t()} | {:error, Error.t()}
  def bfs_reach(%Matrix{shape: {n, _}} = adj, source, opts \\ []) do
    with :ok <- validate_source(source, n) do
      backend = Config.resolve_backend(opts)

      {:ok, frontier} = Vector.from_entries(n, [{source, true}], :bool, backend: backend)
      {:ok, visited} = Vector.dup(frontier, backend: backend)
      bfs_reach_loop(adj, frontier, visited, opts)
    end
  end

  defp bfs_reach_loop(adj, frontier, visited, opts) do
    max_iter = Keyword.get(opts, :max_iter, @default_max_iter)
    backend = Config.resolve_backend(opts)

    bfs_reach_loop(adj, frontier, visited, 0, max_iter, backend)
  end

  defp bfs_reach_loop(_adj, _frontier, visited, iter, max_iter, _backend) when iter >= max_iter do
    {:ok, visited}
  end

  defp bfs_reach_loop(adj, frontier, visited, iter, max_iter, backend) do
    {:ok, nvals} = Vector.nvals(frontier)

    if nvals == 0 do
      {:ok, visited}
    else
      mask = Mask.complement(visited)

      with {:ok, new_frontier} <-
             ok(Vector.vxm(frontier, adj, :lor_land, mask: mask, backend: backend)),
           {:ok, new_visited} <-
             ok(Vector.ewise_add(visited, new_frontier, :lor, backend: backend)) do
        maybe_free(frontier, backend)
        maybe_free(visited, backend)
        bfs_reach_loop(adj, new_frontier, new_visited, iter + 1, max_iter, backend)
      end
    end
  end

  @doc """
  BFS with hop-distance tracking from a source vertex.

  Returns an int64 vector where `levels[i]` is the hop distance from the
  source to vertex i. Vertices not reachable from the source have no
  stored entry (structural zero = 0).

  Uses `:lor_land` for frontier expansion, then stamps level numbers in
  Elixir and merges via `ewise_add` with `:min` monoid.
  """
  @spec bfs_levels(Matrix.t(), non_neg_integer(), keyword()) ::
          {:ok, Vector.t()} | {:error, Error.t()}
  def bfs_levels(%Matrix{shape: {n, _}} = adj, source, opts \\ []) do
    with :ok <- validate_source(source, n) do
      backend = Config.resolve_backend(opts)
      max_iter = Keyword.get(opts, :max_iter, @default_max_iter)

      with {:ok, frontier} <- Vector.from_entries(n, [{source, true}], :bool, backend: backend),
           {:ok, levels} <- Vector.from_entries(n, [{source, 0}], :int64, backend: backend) do
        bfs_levels_loop(adj, frontier, levels, 0, max_iter, n, backend)
      end
    end
  end

  defp bfs_levels_loop(_adj, _frontier, levels, level, max_iter, _n, _backend)
       when level >= max_iter do
    {:ok, levels}
  end

  defp bfs_levels_loop(adj, frontier, levels, level, max_iter, n, backend) do
    {:ok, nvals} = Vector.nvals(frontier)

    if nvals == 0 do
      {:ok, levels}
    else
      bfs_levels_expand(adj, frontier, levels, level, max_iter, n, backend)
    end
  end

  defp bfs_levels_expand(adj, frontier, levels, level, max_iter, n, backend) do
    levels_mask = Mask.complement(levels)

    with {:ok, new_frontier} <-
           ok(Vector.vxm(frontier, adj, :lor_land, mask: levels_mask, backend: backend)),
         {:ok, frontier_entries} <- Vector.to_entries(new_frontier),
         level_entries <- Enum.map(frontier_entries, fn {idx, _} -> {idx, level + 1} end),
         {:ok, level_vec} <- Vector.from_entries(n, level_entries, :int64, backend: backend),
         {:ok, new_levels} <- ok(Vector.ewise_add(levels, level_vec, :min, backend: backend)) do
      maybe_free(frontier, backend)
      maybe_free(levels, backend)
      bfs_levels_loop(adj, new_frontier, new_levels, level + 1, max_iter, n, backend)
    end
  end

  @doc """
  Single-source shortest path using the Bellman-Ford algorithm.

  Returns an fp64 vector where `dist[i]` is the shortest distance from
  the source to vertex i. Unreachable vertices have no stored entry.

  The adjacency matrix must be fp64 with edge weights as entries.
  Uses the `:min_plus_fp64` semiring. Converges when distances stop changing.

  Options:
  - `:max_iter` -- maximum iterations (default: 100)
  - `:infinity` -- sentinel value for unreachable vertices (default: 1.0e18)
  - `:backend` -- override the default backend
  """
  @spec sssp(Matrix.t(), non_neg_integer(), keyword()) ::
          {:ok, Vector.t()} | {:error, Error.t()}
  def sssp(%Matrix{shape: {n, _}} = adj, source, opts \\ []) do
    with :ok <- validate_source(source, n) do
      backend = Config.resolve_backend(opts)
      max_iter = Keyword.get(opts, :max_iter, @default_max_iter)
      inf = Keyword.get(opts, :infinity, @sssp_inf)

      entries = for i <- 0..(n - 1), do: {i, if(i == source, do: 0.0, else: inf)}

      with {:ok, dist} <- Vector.from_entries(n, entries, :fp64, backend: backend),
           {:ok, final} <- sssp_loop(adj, dist, 0, max_iter, backend) do
        sssp_strip_inf(final, n, inf, backend)
      end
    end
  end

  defp sssp_strip_inf(dist, n, inf, backend) do
    {:ok, entries} = Vector.to_entries(dist)
    reachable = Enum.reject(entries, fn {_, v} -> v >= inf end)
    Vector.from_entries(n, reachable, :fp64, backend: backend)
  end

  defp sssp_loop(_adj, dist, iter, max_iter, _backend) when iter >= max_iter do
    {:ok, dist}
  end

  defp sssp_loop(adj, dist, iter, max_iter, backend) do
    with {:ok, candidates} <- ok(Vector.vxm(dist, adj, :min_plus_fp64, backend: backend)),
         {:ok, dist_new} <- ok(Vector.ewise_add(dist, candidates, :min, backend: backend)) do
      if converged_exact?(dist, dist_new, backend) do
        maybe_free(candidates, backend)
        maybe_free(dist_new, backend)
        {:ok, dist}
      else
        maybe_free(candidates, backend)
        maybe_free(dist, backend)
        sssp_loop(adj, dist_new, iter + 1, max_iter, backend)
      end
    end
  end

  @doc """
  Triangle counting in an undirected graph.

  Returns the number of triangles. The adjacency matrix must be bool
  and symmetric (undirected). Uses the Cuenta method: mxm of the lower
  triangle with the full adjacency, masked to the lower triangle.
  """
  @spec triangle_count(Matrix.t(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, Error.t()}
  def triangle_count(%Matrix{} = adj, opts \\ []) do
    backend = Config.resolve_backend(opts)
    {n, _} = adj.shape

    with {:ok, adj_coo} <- Matrix.to_coo(adj) do
      lower_int = for {r, c, _v} <- adj_coo, r > c, do: {r, c, 1}
      full_int = for {r, c, _v} <- adj_coo, do: {r, c, 1}

      with {:ok, lint} <- Matrix.from_coo(n, n, lower_int, :int64, backend: backend),
           {:ok, aint} <- Matrix.from_coo(n, n, full_int, :int64, backend: backend),
           {:ok, cmat} <-
             ok(Matrix.mxm(lint, aint, :plus_times, mask: Mask.new(lint), backend: backend)),
           {:ok, vvec} <- ok(Matrix.reduce(cmat, :plus, backend: backend)),
           {:ok, sval} <- ok(Vector.reduce(vvec, :plus, backend: backend)) do
        count = Scalar.value(sval)
        maybe_free(lint, backend)
        maybe_free(aint, backend)
        maybe_free(cmat, backend)
        maybe_free(vvec, backend)
        {:ok, div(count, 2)}
      end
    end
  end

  @doc """
  Connected components via multi-source BFS.

  Returns an int64 vector where `component[i]` is the component ID for
  vertex i. Vertices in the same connected component share the same ID.

  Uses `:lor_land` for BFS reachability and `:plus_min` for merging
  component IDs. Works with only built-in semirings.
  """
  @spec connected_components(Matrix.t(), keyword()) ::
          {:ok, Vector.t()} | {:error, Error.t()}
  def connected_components(%Matrix{shape: {n, _}} = adj, opts \\ []) do
    backend = Config.resolve_backend(opts)

    component_entries = for i <- 0..(n - 1), do: {i, i}

    with {:ok, component} <- Vector.from_entries(n, component_entries, :int64, backend: backend),
         {:ok, unvisited} <-
           Vector.from_entries(n, for(i <- 0..(n - 1), do: {i, true}), :bool, backend: backend) do
      cc_loop(adj, component, unvisited, n, backend)
    end
  end

  defp cc_loop(adj, component, unvisited, _n, backend) do
    {:ok, nvals} = Vector.nvals(unvisited)

    if nvals == 0 do
      maybe_free(unvisited, backend)
      {:ok, component}
    else
      cc_expand_component(adj, component, unvisited, backend)
    end
  end

  defp cc_expand_component(adj, component, unvisited, backend) do
    {:ok, [{v, _} | _]} = Vector.to_entries(unvisited)

    with {:ok, visited} <- bfs_reach(adj, v, backend: backend),
         {:ok, comp_val} <- Vector.extract(component, v),
         {:ok, visited_entries} <- Vector.to_entries(visited),
         {:ok, vec_size} <- Vector.size(component),
         stamp_entries <- Enum.map(visited_entries, fn {i, _} -> {i, comp_val} end),
         {:ok, stamp_vec} <-
           Vector.from_entries(vec_size, stamp_entries, :int64, backend: backend),
         {:ok, new_component} <-
           ok(Vector.ewise_add(component, stamp_vec, :min, backend: backend)),
         visited_complement <- Mask.complement(visited),
         {:ok, new_unvisited} <-
           ok(
             Vector.ewise_mult(unvisited, unvisited, :land,
               mask: visited_complement,
               backend: backend
             )
           ) do
      maybe_free(component, backend)
      maybe_free(unvisited, backend)
      maybe_free(visited, backend)
      maybe_free(stamp_vec, backend)
      cc_loop(adj, new_component, new_unvisited, nil, backend)
    end
  end

  @doc """
  In-degree and out-degree calculation.

  Returns a map with `:in_degree` and `:out_degree` vectors (int64).
  For bool adjacency, degree values count the number of edges.
  """
  @spec degree(Matrix.t(), keyword()) ::
          {:ok, %{in_degree: Vector.t(), out_degree: Vector.t()}} | {:error, Error.t()}
  def degree(%Matrix{} = adj, opts \\ []) do
    backend = Config.resolve_backend(opts)
    desc = Descriptor.new(inp0_transpose: :transpose)

    with {:ok, adj_int} <- bool_to_int64(adj, backend),
         {:ok, out_deg} <- ok(Matrix.reduce(adj_int, :plus, backend: backend)),
         {:ok, in_deg} <- ok(Matrix.reduce(adj_int, :plus, descriptor: desc, backend: backend)) do
      maybe_free(adj_int, backend)
      {:ok, %{in_degree: in_deg, out_degree: out_deg}}
    end
  end

  @doc """
  PageRank via power iteration with damping and dangling-node correction.

  Returns an fp64 vector of PageRank scores. The adjacency matrix should
  be bool (unweighted). Uses `:plus_times_fp64` semiring.

  ## Options

  - `:damping` -- damping factor (default: 0.85)
  - `:max_iter` -- maximum iterations (default: 100)
  - `:tol` -- convergence tolerance (default: 1.0e-6)
  """
  @spec pagerank(Matrix.t(), keyword()) ::
          {:ok, Vector.t()} | {:error, Error.t()}
  def pagerank(%Matrix{shape: {n, _}} = adj, opts \\ []) do
    backend = Config.resolve_backend(opts)
    damping = Keyword.get(opts, :damping, 0.85)
    max_iter = Keyword.get(opts, :max_iter, @default_max_iter)
    tol = Keyword.get(opts, :tol, @default_tol)

    with {:ok, adj_int} <- bool_to_int64(adj, backend),
         {:ok, at} <- ok(Matrix.transpose(adj_int, backend: backend)),
         {:ok, out_deg} <- ok(Matrix.reduce(adj_int, :plus, backend: backend)),
         {:ok, recip} <- build_reciprocal_degree(out_deg, n, backend),
         r_init = 1.0 / n,
         r_entries <- for(i <- 0..(n - 1), do: {i, r_init}),
         {:ok, r} <- Vector.from_entries(n, r_entries, :fp64, backend: backend) do
      maybe_free(adj_int, backend)

      pagerank_loop(at, out_deg, recip, r, %{
        n: n,
        damping: damping,
        tol: tol,
        iter: 0,
        max_iter: max_iter,
        backend: backend
      })
    end
  end

  defp pagerank_loop(_at, _out_deg, _recip, r, %{
         iter: iter,
         max_iter: max_iter
       })
       when iter >= max_iter do
    {:ok, r}
  end

  defp pagerank_loop(at, out_deg, recip, r, %{
         n: n,
         damping: damping,
         tol: tol,
         iter: iter,
         max_iter: max_iter,
         backend: backend
       }) do
    with {:ok, r_scaled} <- ok(Vector.ewise_mult(r, recip, :times_fp64, backend: backend)),
         {:ok, r_new} <- ok(Matrix.mxv(at, r_scaled, :plus_times_fp64, backend: backend)),
         {:ok, r_new} <- scale_and_shift(r_new, damping, (1 - damping) / n, n, backend),
         {:ok, r_new} <- apply_dangling_correction(r_new, r, out_deg, damping, n, backend) do
      if converged_tolerance?(r, r_new, tol, backend) do
        maybe_free(r_scaled, backend)
        maybe_free(r, backend)
        {:ok, r_new}
      else
        maybe_free(r_scaled, backend)
        maybe_free(r, backend)

        pagerank_loop(at, out_deg, recip, r_new, %{
          n: n,
          damping: damping,
          tol: tol,
          iter: iter + 1,
          max_iter: max_iter,
          backend: backend
        })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 6C: Query Foundations
  # ---------------------------------------------------------------------------

  @doc """
  Generic fixed-point iteration primitive.

  Applies `step_fn` to `initial` repeatedly until convergence or
  `max_iter` is reached. Returns `{:ok, final_value, info}` where
  info contains `%{iterations: n, converged: boolean}`.

  ## Options

  - `:max_iter` -- maximum iterations (default: 100)
  - `:tol` -- convergence tolerance for fp64 (default: 1.0e-6)
  - `:convergence_fn` -- custom convergence check `(old, new -> boolean)`
  """
  @spec fixed_point(term(), (term() -> {:ok, term()} | {:error, Error.t()}), keyword()) ::
          {:ok, term(), map()} | {:error, Error.t()}
  def fixed_point(initial, step_fn, opts \\ []) do
    max_iter = Keyword.get(opts, :max_iter, @default_max_iter)
    tol = Keyword.get(opts, :tol, @default_tol)
    conv_fn = Keyword.get(opts, :convergence_fn)

    fixed_point_loop(initial, step_fn, conv_fn, tol, 0, max_iter)
  end

  defp fixed_point_loop(current, _step_fn, _conv_fn, _tol, iter, max_iter)
       when iter >= max_iter do
    {:ok, current, %{iterations: iter, converged: false}}
  end

  defp fixed_point_loop(current, step_fn, conv_fn, tol, iter, max_iter) do
    case step_fn.(current) do
      {:ok, next} ->
        converged =
          if conv_fn do
            conv_fn.(current, next)
          else
            default_converged?(current, next, tol)
          end

        if converged do
          {:ok, next, %{iterations: iter + 1, converged: true}}
        else
          fixed_point_loop(next, step_fn, conv_fn, tol, iter + 1, max_iter)
        end

      {:error, _} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_source(source, n) when source >= 0 and source < n, do: :ok
  defp validate_source(source, _n), do: Error.error({:index_out_of_bounds, source, :source, 0})

  defp bool_to_int64(%Matrix{type: :int64} = m, _backend), do: {:ok, m}

  defp bool_to_int64(%Matrix{shape: {nrows, ncols}, type: :bool} = m, backend) do
    {:ok, coo} = ok(Matrix.to_coo(m))
    int_coo = Enum.map(coo, fn {r, c, true} -> {r, c, 1} end)
    Matrix.from_coo(nrows, ncols, int_coo, :int64, backend: backend)
  end

  defp bool_to_int64(%Matrix{shape: {nrows, ncols}, type: :fp64} = m, backend) do
    {:ok, coo} = ok(Matrix.to_coo(m))
    int_coo = Enum.map(coo, fn {r, c, v} -> {r, c, trunc(v)} end)
    Matrix.from_coo(nrows, ncols, int_coo, :int64, backend: backend)
  end

  defp converged_exact?(old_vec, new_vec, _backend) do
    {:ok, old_entries} = Vector.to_entries(old_vec)
    {:ok, new_entries} = Vector.to_entries(new_vec)
    Enum.sort(old_entries) == Enum.sort(new_entries)
  end

  defp converged_tolerance?(old_vec, new_vec, tol, _backend) do
    {:ok, old_entries} = Vector.to_entries(old_vec)
    {:ok, new_entries} = Vector.to_entries(new_vec)

    old_map = Map.new(old_entries)
    new_map = Map.new(new_entries)
    all_keys = MapSet.union(MapSet.new(Map.keys(old_map)), MapSet.new(Map.keys(new_map)))

    Enum.all?(all_keys, fn k ->
      abs(Map.get(old_map, k, 0.0) - Map.get(new_map, k, 0.0)) < tol
    end)
  end

  defp build_reciprocal_degree(out_deg, n, backend) do
    {:ok, entries} = Vector.to_entries(out_deg)
    degree_map = Map.new(entries)

    recip_entries =
      for i <- 0..(n - 1) do
        case Map.get(degree_map, i) do
          nil -> {i, 0.0}
          0 -> {i, 0.0}
          d -> {i, 1.0 / d}
        end
      end

    Vector.from_entries(n, recip_entries, :fp64, backend: backend)
  end

  defp scale_and_shift(vec, alpha, beta, n, backend) do
    with {:ok, vec_entries} <- Vector.to_entries(vec),
         scaled_entries <- Enum.map(vec_entries, fn {i, v} -> {i, v * alpha + beta} end),
         {:ok, result} <- Vector.from_entries(n, scaled_entries, :fp64, backend: backend) do
      maybe_free(vec, backend)
      {:ok, result}
    end
  end

  defp apply_dangling_correction(r_new, r, out_deg, damping, n, backend) do
    {:ok, deg_entries} = Vector.to_entries(out_deg)
    {:ok, r_entries} = Vector.to_entries(r)
    degree_map = Map.new(deg_entries)
    r_map = Map.new(r_entries)

    dangling_sum =
      Enum.reduce(r_map, 0.0, fn {i, val}, acc ->
        case Map.get(degree_map, i) do
          nil -> acc + val
          0 -> acc + val
          _ -> acc
        end
      end)

    if dangling_sum == 0.0 do
      {:ok, r_new}
    else
      shift = damping * dangling_sum / n
      apply_shift(r_new, shift, n, backend)
    end
  end

  defp apply_shift(r_new, shift, n, backend) do
    with {:ok, entries} <- Vector.to_entries(r_new),
         shifted <- Enum.map(entries, fn {i, v} -> {i, v + shift} end),
         {:ok, result} <- Vector.from_entries(n, shifted, :fp64, backend: backend) do
      maybe_free(r_new, backend)
      {:ok, result}
    end
  end

  defp default_converged?(%Matrix{} = old, %Matrix{} = new, _tol) do
    {:ok, old_coo} = ok(Matrix.to_coo(old))
    {:ok, new_coo} = ok(Matrix.to_coo(new))
    Enum.sort(old_coo) == Enum.sort(new_coo)
  end

  defp default_converged?(%Vector{} = old, %Vector{} = new, tol) when tol > 0 do
    {:ok, old_entries} = ok(Vector.to_entries(old))
    {:ok, new_entries} = ok(Vector.to_entries(new))
    old_map = Map.new(old_entries)
    new_map = Map.new(new_entries)

    all_keys = MapSet.union(MapSet.new(Map.keys(old_map)), MapSet.new(Map.keys(new_map)))

    Enum.all?(all_keys, fn k ->
      abs(Map.get(old_map, k, 0.0) - Map.get(new_map, k, 0.0)) < tol
    end)
  end

  defp default_converged?(%Vector{} = old, %Vector{} = new, _tol) do
    {:ok, old_entries} = ok(Vector.to_entries(old))
    {:ok, new_entries} = ok(Vector.to_entries(new))
    Enum.sort(old_entries) == Enum.sort(new_entries)
  end

  defp default_converged?(_old, _new, _tol), do: false
end
