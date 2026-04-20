defmodule GraphBLAS.Backend.Elixir do
  @moduledoc """
  Pure Elixir backend implementing the `GraphBLAS.Backend` behaviour.

  This is the correctness-first reference implementation. It uses the
  simplest possible data structures to make each operation easy to
  understand, inspect, and verify by hand.

  **Do not benchmark this backend and draw conclusions about the
  library's performance.** It is intentionally not optimized.

  ## Purpose

  1. **Semantic oracle** -- defines what each operation must produce;
     future backends (SuiteSparse) must match these results exactly.

  2. **API validation** -- proves the backend behaviour contract is
     complete and well-typed before native code is written.

  3. **Tutorial vehicle** -- readable Elixir code that shows exactly
     what each operation computes.

  4. **Regression baseline** -- test oracle for future backend parity.

  ## Data representation

  Matrices use flat maps with tuple keys:

      %{entries: %{{0, 1} => 5, {1, 2} => 7}, nrows: 3, ncols: 3, type: :int64}

  Vectors use flat maps with integer keys:

      %{entries: %{0 => 4, 2 => 8}, size: 4, type: :int64}

  These representations are chosen for clarity, not performance.
  Single-level lookups, trivial pattern matching, easy inspection.
  """

  @behaviour GraphBLAS.Backend

  alias GraphBLAS.{Matrix, Vector, Scalar, Semiring, Monoid, Types, Error}

  #############################################################################
  # Matrix callbacks
  #############################################################################

  @impl GraphBLAS.Backend
  def matrix_new(nrows, ncols, type, _opts) do
    with :ok <- validate_dimensions(nrows, ncols),
         :ok <- Types.validate_scalar_type(type) do
      data = %{entries: %{}, nrows: nrows, ncols: ncols, type: type}
      {:ok, %Matrix{shape: {nrows, ncols}, type: type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_from_coo(nrows, ncols, entries, type, opts) do
    with :ok <- validate_dimensions(nrows, ncols),
         :ok <- Types.validate_scalar_type(type),
         :ok <- validate_entries(entries, nrows, ncols) do
      monoid = Keyword.get(opts, :combine_monoid, :plus)
      combined = combine_coo_entries(entries, monoid)
      data = %{entries: combined, nrows: nrows, ncols: ncols, type: type}
      {:ok, %Matrix{shape: {nrows, ncols}, type: type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_nvals(%Matrix{data: data}) do
    {:ok, map_size(data.entries)}
  end

  @impl GraphBLAS.Backend
  def matrix_shape(%Matrix{shape: shape}) do
    {:ok, shape}
  end

  @impl GraphBLAS.Backend
  def matrix_type(%Matrix{type: type}) do
    {:ok, type}
  end

  @impl GraphBLAS.Backend
  def matrix_to_coo(%Matrix{data: data}) do
    entries =
      data.entries
      |> Enum.map(fn {{r, c}, v} -> {r, c, v} end)
      |> Enum.sort_by(fn {r, c, _v} -> {r, c} end)

    {:ok, entries}
  end

  @impl GraphBLAS.Backend
  def matrix_mxm(%Matrix{} = a, %Matrix{} = b, semiring, _opts) do
    with {:ok, sr} <- resolve_semiring(semiring),
         :ok <- validate_mxm_dims(a, b) do
      {nrows_a, _ncols_a} = a.shape
      {_nrows_b, ncols_b} = b.shape
      result_type = sr.type
      multiply_fn = resolve_operator_fn(sr.multiply)
      add_fn = resolve_operator_fn(sr.add)

      # Flat map approach: iterate A entries, for each {i,k} check B for {k,j}
      result_entries =
        Enum.reduce(a.data.entries, %{}, fn {{i, k}, a_val}, outer_acc ->
          Enum.reduce(b.data.entries, outer_acc, fn {{k2, j}, b_val}, inner_acc ->
            if k == k2 do
              product = apply_op(multiply_fn, a_val, b_val)
              Map.update(inner_acc, {i, j}, product, fn existing ->
                apply_op(add_fn, existing, product)
              end)
            else
              inner_acc
            end
          end)
        end)

      data = %{entries: result_entries, nrows: nrows_a, ncols: ncols_b, type: result_type}
      {:ok, %Matrix{shape: {nrows_a, ncols_b}, type: result_type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_mxv(%Matrix{} = matrix, %Vector{} = vector, semiring, _opts) do
    with {:ok, sr} <- resolve_semiring(semiring),
         :ok <- validate_mxv_dims(matrix, vector) do
      result_type = sr.type
      multiply_fn = resolve_operator_fn(sr.multiply)
      add_fn = resolve_operator_fn(sr.add)

      result_entries =
        Enum.reduce(matrix.data.entries, %{}, fn {{i, k}, a_val}, acc ->
          case Map.get(vector.data.entries, k) do
            nil -> acc
            b_val ->
              product = apply_op(multiply_fn, a_val, b_val)
              Map.update(acc, i, product, fn existing -> apply_op(add_fn, existing, product) end)
          end
        end)

      nrows = elem(matrix.shape, 0)
      data = %{entries: result_entries, size: nrows, type: result_type}
      {:ok, %Vector{size: nrows, type: result_type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_ewise_add(%Matrix{} = a, %Matrix{} = b, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid),
         :ok <- validate_same_shape(a, b) do
      op_fn = resolve_operator_fn(m.operator)
      combined = Map.merge(a.data.entries, b.data.entries, fn _key, v1, v2 -> apply_op(op_fn, v1, v2) end)

      data = %{entries: combined, nrows: elem(a.shape, 0), ncols: elem(a.shape, 1), type: a.type}
      {:ok, %Matrix{shape: a.shape, type: a.type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_ewise_mult(%Matrix{} = a, %Matrix{} = b, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid),
         :ok <- validate_same_shape(a, b) do
      op_fn = resolve_operator_fn(m.operator)
      intersection = Map.intersect(a.data.entries, b.data.entries, fn _key, v1, v2 -> apply_op(op_fn, v1, v2) end)

      data = %{entries: intersection, nrows: elem(a.shape, 0), ncols: elem(a.shape, 1), type: a.type}
      {:ok, %Matrix{shape: a.shape, type: a.type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_reduce(%Matrix{} = matrix, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid) do
      op_fn = resolve_operator_fn(m.operator)

      result_entries =
        matrix.data.entries
        |> Enum.group_by(fn {{r, _c}, _v} -> r end, fn {{_r, _c}, v} -> v end)
        |> Map.new(fn {row, vals} ->
          {row, Enum.reduce(vals, fn a, b -> apply_op(op_fn, b, a) end)}
        end)

      data = %{entries: result_entries, size: elem(matrix.shape, 0), type: matrix.type}
      {:ok, %Vector{size: elem(matrix.shape, 0), type: matrix.type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_transpose(%Matrix{} = matrix, _opts) do
    {nrows, ncols} = matrix.shape

    result_entries =
      matrix.data.entries
      |> Enum.map(fn {{r, c}, v} -> {{c, r}, v} end)
      |> Map.new()

    data = %{entries: result_entries, nrows: ncols, ncols: nrows, type: matrix.type}
    {:ok, %Matrix{shape: {ncols, nrows}, type: matrix.type, data: data}}
  end

  @impl GraphBLAS.Backend
  def matrix_to_dense(%Matrix{data: data, shape: {nrows, ncols}, type: type}) do
    default = default_value(type)
    rows =
      for r <- 0..(nrows - 1) do
        for c <- 0..(ncols - 1) do
          Map.get(data.entries, {r, c}, default)
        end
      end
    {:ok, rows}
  end

  #############################################################################
  # Vector callbacks
  #############################################################################

  @impl GraphBLAS.Backend
  def vector_new(size, type, _opts) do
    with :ok <- validate_size(size),
         :ok <- Types.validate_scalar_type(type) do
      data = %{entries: %{}, size: size, type: type}
      {:ok, %Vector{size: size, type: type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_from_entries(size, entries, type, opts) do
    with :ok <- validate_size(size),
         :ok <- Types.validate_scalar_type(type),
         :ok <- validate_vector_entries(entries, size) do
      monoid = Keyword.get(opts, :combine_monoid, :plus)
      combined = combine_vector_entries(entries, monoid)
      data = %{entries: combined, size: size, type: type}
      {:ok, %Vector{size: size, type: type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_nvals(%Vector{data: data}) do
    {:ok, map_size(data.entries)}
  end

  @impl GraphBLAS.Backend
  def vector_size(%Vector{size: size}) do
    {:ok, size}
  end

  @impl GraphBLAS.Backend
  def vector_type(%Vector{type: type}) do
    {:ok, type}
  end

  @impl GraphBLAS.Backend
  def vector_to_entries(%Vector{data: data}) do
    entries = data.entries |> Enum.sort_by(fn {idx, _val} -> idx end)
    {:ok, entries}
  end

  @impl GraphBLAS.Backend
  def vector_vxm(%Vector{} = vector, %Matrix{} = matrix, semiring, _opts) do
    with {:ok, sr} <- resolve_semiring(semiring),
         :ok <- validate_vxm_dims(vector, matrix) do
      result_type = sr.type
      multiply_fn = resolve_operator_fn(sr.multiply)
      add_fn = resolve_operator_fn(sr.add)

      result_entries =
        Enum.reduce(vector.data.entries, %{}, fn {k, v_val}, acc ->
          Enum.reduce(matrix.data.entries, acc, fn {{k2, j}, m_val}, inner_acc ->
            if k == k2 do
              product = apply_op(multiply_fn, v_val, m_val)
              Map.update(inner_acc, j, product, fn existing -> apply_op(add_fn, existing, product) end)
            else
              inner_acc
            end
          end)
        end)

      result_size = elem(matrix.shape, 1)
      data_result = %{entries: result_entries, size: result_size, type: result_type}
      {:ok, %Vector{size: result_size, type: result_type, data: data_result}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_ewise_add(%Vector{} = a, %Vector{} = b, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid),
         :ok <- validate_same_vector_size(a, b) do
      op_fn = resolve_operator_fn(m.operator)
      combined = Map.merge(a.data.entries, b.data.entries, fn _k, v1, v2 -> apply_op(op_fn, v1, v2) end)
      data = %{entries: combined, size: a.size, type: a.type}
      {:ok, %Vector{size: a.size, type: a.type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_ewise_mult(%Vector{} = a, %Vector{} = b, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid),
         :ok <- validate_same_vector_size(a, b) do
      op_fn = resolve_operator_fn(m.operator)
      intersection = Map.intersect(a.data.entries, b.data.entries, fn _k, v1, v2 -> apply_op(op_fn, v1, v2) end)
      data = %{entries: intersection, size: a.size, type: a.type}
      {:ok, %Vector{size: a.size, type: a.type, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_reduce(%Vector{} = vector, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid) do
      op_fn = resolve_operator_fn(m.operator)
      vals = Map.values(vector.data.entries)

      result =
        case vals do
          [] -> m.identity
          [single] -> single
          _ -> Enum.reduce(vals, fn a, b -> apply_op(op_fn, b, a) end)
        end

      {:ok, %Scalar{type: m.type, value: result}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_to_list(%Vector{data: data, size: size, type: type}) do
    default = default_value(type)
    list = for i <- 0..(size - 1), do: Map.get(data.entries, i, default)
    {:ok, list}
  end

  #############################################################################
  # Private helpers
  #############################################################################

  defp validate_dimensions(nrows, ncols) when nrows >= 0 and ncols >= 0, do: :ok
  defp validate_dimensions(nrows, ncols), do: Error.error({:invalid_argument, "dimensions must be non-negative, got {#{nrows}, #{ncols}}"})

  defp validate_size(size) when size >= 0, do: :ok
  defp validate_size(size), do: Error.error({:invalid_argument, "vector size must be non-negative, got #{size}"})

  defp validate_entries([], _nrows, _ncols), do: :ok
  defp validate_entries([{r, c, _v} | rest], nrows, ncols) do
    cond do
      r < 0 or r >= nrows -> Error.error({:index_out_of_bounds, r, :row, nrows})
      c < 0 or c >= ncols -> Error.error({:index_out_of_bounds, c, :col, ncols})
      true -> validate_entries(rest, nrows, ncols)
    end
  end

  defp validate_vector_entries([], _size), do: :ok
  defp validate_vector_entries([{idx, _v} | rest], size) do
    if idx < 0 or idx >= size do
      Error.error({:index_out_of_bounds, idx, :index, size})
    else
      validate_vector_entries(rest, size)
    end
  end

  defp validate_mxm_dims(%Matrix{shape: {_, ncols_a}}, %Matrix{shape: {nrows_b, _}}) do
    if ncols_a == nrows_b, do: :ok, else: Error.error({:dimension_mismatch, {ncols_a, nrows_b}, "ncols(A) != nrows(B)"})
  end

  defp validate_mxv_dims(%Matrix{shape: {_, ncols}}, %Vector{size: size}) do
    if ncols == size, do: :ok, else: Error.error({:dimension_mismatch, {ncols, size}, "ncols(matrix) != size(vector)"})
  end

  defp validate_vxm_dims(%Vector{size: size}, %Matrix{shape: {nrows, _}}) do
    if size == nrows, do: :ok, else: Error.error({:dimension_mismatch, {size, nrows}, "size(vector) != nrows(matrix)"})
  end

  defp validate_same_shape(%Matrix{shape: s1}, %Matrix{shape: s2}) do
    if s1 == s2, do: :ok, else: Error.error({:dimension_mismatch, s2, s1})
  end

  defp validate_same_vector_size(%Vector{size: s1}, %Vector{size: s2}) do
    if s1 == s2, do: :ok, else: Error.error({:dimension_mismatch, s2, s1})
  end

  defp combine_coo_entries(entries, monoid) do
    {:ok, m} = resolve_monoid(monoid)
    op_fn = resolve_operator_fn(m.operator)

    entries
    |> Enum.group_by(fn {r, c, _v} -> {r, c} end, fn {_r, _c, v} -> v end)
    |> Map.new(fn {{r, c}, vals} ->
      combined = Enum.reduce(vals, fn a, b -> apply_op(op_fn, b, a) end)
      {{r, c}, combined}
    end)
  end

  defp combine_vector_entries(entries, monoid) do
    {:ok, m} = resolve_monoid(monoid)
    op_fn = resolve_operator_fn(m.operator)

    entries
    |> Enum.group_by(fn {idx, _v} -> idx end, fn {_idx, v} -> v end)
    |> Map.new(fn {idx, vals} ->
      combined = Enum.reduce(vals, fn a, b -> apply_op(op_fn, b, a) end)
      {idx, combined}
    end)
  end

  defp resolve_semiring(name) when is_atom(name), do: Semiring.resolve(name)
  defp resolve_semiring(%Semiring{} = s), do: {:ok, s}

  defp resolve_monoid(name) when is_atom(name), do: Monoid.resolve(name)
  defp resolve_monoid(%Monoid{} = m), do: {:ok, m}

  defp resolve_operator_fn(:plus), do: &Kernel.+/2
  defp resolve_operator_fn(:times), do: &Kernel.*/2
  defp resolve_operator_fn(:min), do: &min/2
  defp resolve_operator_fn(:max), do: &max/2
  defp resolve_operator_fn(:land), do: &Kernel.and/2
  defp resolve_operator_fn(:lor), do: &Kernel.or/2
  defp resolve_operator_fn(:lxor), do: &Bitwise.bxor/2
  defp resolve_operator_fn(fun) when is_function(fun, 2), do: fun

  defp apply_op(fun, a, b), do: fun.(a, b)

  defp default_value(:bool), do: false
  defp default_value(:fp32), do: 0.0
  defp default_value(:fp64), do: 0.0
  defp default_value(_), do: 0
end