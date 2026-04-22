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

  alias GraphBLAS.{Descriptor, Error, Mask, Matrix, Monoid, Scalar, Semiring, Types, Vector}

  #############################################################################
  # Matrix callbacks
  #############################################################################

  @impl GraphBLAS.Backend
  def matrix_new(nrows, ncols, type, _opts) do
    with :ok <- validate_dimensions(nrows, ncols),
         :ok <- Types.validate_scalar_type(type) do
      data = %{entries: %{}, nrows: nrows, ncols: ncols, type: type}
      {:ok, %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: data}}
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
      {:ok, %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: data}}
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
  def matrix_mxm(%Matrix{} = a, %Matrix{} = b, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      {a, b} = apply_descriptor_inputs(a, b, opts)

      with :ok <- validate_mxm_dims(a, b) do
        {nrows_a, _ncols_a} = a.shape
        {_nrows_b, ncols_b} = b.shape
        multiply_fn = resolve_operator_fn(sr.multiply)
        add_fn = resolve_operator_fn(sr.add)

        result_entries = mxm_multiply(a, b, multiply_fn, add_fn)
        masked = apply_matrix_mask(result_entries, opts, nrows_a, ncols_b)
        data = %{entries: masked, nrows: nrows_a, ncols: ncols_b, type: sr.type}
        {:ok, %Matrix{shape: {nrows_a, ncols_b}, type: sr.type, backend: __MODULE__, data: data}}
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_mxv(%Matrix{} = matrix, %Vector{} = vector, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      {matrix, _} = apply_descriptor_inputs(matrix, nil, opts)

      with :ok <- validate_mxv_dims(matrix, vector) do
        multiply_fn = resolve_operator_fn(sr.multiply)
        add_fn = resolve_operator_fn(sr.add)

        result_entries = mxv_multiply(matrix, vector, multiply_fn, add_fn)
        nrows = elem(matrix.shape, 0)
        masked = apply_vector_mask(result_entries, opts, nrows)
        data = %{entries: masked, size: nrows, type: sr.type}
        {:ok, %Vector{size: nrows, type: sr.type, backend: __MODULE__, data: data}}
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_ewise_add(%Matrix{} = a, %Matrix{} = b, monoid, opts) do
    with {:ok, m} <- resolve_monoid(monoid),
         :ok <- validate_same_shape(a, b) do
      op_fn = resolve_operator_fn(m.operator)

      combined =
        Map.merge(a.data.entries, b.data.entries, fn _key, v1, v2 -> apply_op(op_fn, v1, v2) end)

      nrows = elem(a.shape, 0)
      ncols = elem(a.shape, 1)
      masked = apply_matrix_mask(combined, opts, nrows, ncols)
      data = %{entries: masked, nrows: nrows, ncols: ncols, type: a.type}
      {:ok, %Matrix{shape: a.shape, type: a.type, backend: __MODULE__, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_ewise_mult(%Matrix{} = a, %Matrix{} = b, monoid, opts) do
    with {:ok, m} <- resolve_monoid(monoid),
         :ok <- validate_same_shape(a, b) do
      op_fn = resolve_operator_fn(m.operator)

      intersection =
        Map.intersect(a.data.entries, b.data.entries, fn _key, v1, v2 ->
          apply_op(op_fn, v1, v2)
        end)

      nrows = elem(a.shape, 0)
      ncols = elem(a.shape, 1)
      masked = apply_matrix_mask(intersection, opts, nrows, ncols)
      data = %{entries: masked, nrows: nrows, ncols: ncols, type: a.type}

      {:ok, %Matrix{shape: a.shape, type: a.type, backend: __MODULE__, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_reduce(%Matrix{} = matrix, monoid, opts) do
    with {:ok, m} <- resolve_monoid(monoid) do
      op_fn = resolve_operator_fn(m.operator)

      result_entries =
        matrix.data.entries
        |> Enum.group_by(fn {{r, _c}, _v} -> r end, fn {{_r, _c}, v} -> v end)
        |> Map.new(fn {row, vals} ->
          {row, Enum.reduce(vals, fn a, b -> apply_op(op_fn, b, a) end)}
        end)

      nrows = elem(matrix.shape, 0)
      masked = apply_vector_mask(result_entries, opts, nrows)
      data = %{entries: masked, size: nrows, type: matrix.type}
      {:ok, %Vector{size: nrows, type: matrix.type, backend: __MODULE__, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_transpose(%Matrix{} = matrix, opts) do
    {nrows, ncols} = matrix.shape

    result_entries =
      matrix.data.entries
      |> Enum.map(fn {{r, c}, v} -> {{c, r}, v} end)
      |> Map.new()

    masked = apply_matrix_mask(result_entries, opts, ncols, nrows)
    data = %{entries: masked, nrows: ncols, ncols: nrows, type: matrix.type}
    {:ok, %Matrix{shape: {ncols, nrows}, type: matrix.type, backend: __MODULE__, data: data}}
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
      {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: data}}
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
      {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: data}}
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
    entries = Enum.sort_by(data.entries, fn {idx, _val} -> idx end)
    {:ok, entries}
  end

  @impl GraphBLAS.Backend
  def vector_vxm(%Vector{} = vector, %Matrix{} = matrix, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      {_, matrix} = apply_descriptor_inputs(nil, matrix, opts)

      with :ok <- validate_vxm_dims(vector, matrix) do
        multiply_fn = resolve_operator_fn(sr.multiply)
        add_fn = resolve_operator_fn(sr.add)

        result_entries = vxm_multiply(vector, matrix, multiply_fn, add_fn)
        result_size = elem(matrix.shape, 1)
        masked = apply_vector_mask(result_entries, opts, result_size)
        data_result = %{entries: masked, size: result_size, type: sr.type}
        {:ok, %Vector{size: result_size, type: sr.type, backend: __MODULE__, data: data_result}}
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_ewise_add(%Vector{} = a, %Vector{} = b, monoid, opts) do
    with {:ok, m} <- resolve_monoid(monoid),
         :ok <- validate_same_vector_size(a, b) do
      op_fn = resolve_operator_fn(m.operator)

      combined =
        Map.merge(a.data.entries, b.data.entries, fn _k, v1, v2 -> apply_op(op_fn, v1, v2) end)

      masked = apply_vector_mask(combined, opts, a.size)
      data = %{entries: masked, size: a.size, type: a.type}
      {:ok, %Vector{size: a.size, type: a.type, backend: __MODULE__, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_ewise_mult(%Vector{} = a, %Vector{} = b, monoid, opts) do
    with {:ok, m} <- resolve_monoid(monoid),
         :ok <- validate_same_vector_size(a, b) do
      op_fn = resolve_operator_fn(m.operator)

      intersection =
        Map.intersect(a.data.entries, b.data.entries, fn _k, v1, v2 -> apply_op(op_fn, v1, v2) end)

      masked = apply_vector_mask(intersection, opts, a.size)
      data = %{entries: masked, size: a.size, type: a.type}
      {:ok, %Vector{size: a.size, type: a.type, backend: __MODULE__, data: data}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_reduce(%Vector{} = vector, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid) do
      result = reduce_values(vector.data.entries, m)
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

  defp validate_dimensions(nrows, ncols),
    do:
      Error.error(
        {:invalid_argument, "dimensions must be non-negative, got {#{nrows}, #{ncols}}"}
      )

  defp validate_size(size) when size >= 0, do: :ok

  defp validate_size(size),
    do: Error.error({:invalid_argument, "vector size must be non-negative, got #{size}"})

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
    if ncols_a == nrows_b,
      do: :ok,
      else: Error.error({:dimension_mismatch, {ncols_a, nrows_b}, "ncols(A) != nrows(B)"})
  end

  defp validate_mxv_dims(%Matrix{shape: {_, ncols}}, %Vector{size: size}) do
    if ncols == size,
      do: :ok,
      else: Error.error({:dimension_mismatch, {ncols, size}, "ncols(matrix) != size(vector)"})
  end

  defp validate_vxm_dims(%Vector{size: size}, %Matrix{shape: {nrows, _}}) do
    if size == nrows,
      do: :ok,
      else: Error.error({:dimension_mismatch, {size, nrows}, "size(vector) != nrows(matrix)"})
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
  defp resolve_operator_fn(:lxor), do: fn a, b -> a != b end
  defp resolve_operator_fn(fun) when is_function(fun, 2), do: fun

  defp apply_op(fun, a, b), do: fun.(a, b)

  defp reduce_values(entries, %{operator: op, identity: identity}) do
    op_fn = resolve_operator_fn(op)
    vals = Map.values(entries)

    case vals do
      [] -> identity
      [single] -> single
      _ -> Enum.reduce(vals, fn a, b -> apply_op(op_fn, b, a) end)
    end
  end

  defp mxm_multiply(a, b, multiply_fn, add_fn) do
    Enum.reduce(a.data.entries, %{}, fn {{i, k}, a_val}, acc ->
      mxm_row(k, i, a_val, b, multiply_fn, add_fn, acc)
    end)
  end

  defp mxm_row(k, i, a_val, b, multiply_fn, add_fn, acc) do
    Enum.reduce(b.data.entries, acc, fn {{k2, j}, b_val}, inner_acc ->
      if k == k2 do
        accumulate_product(inner_acc, {i, j}, a_val, b_val, multiply_fn, add_fn)
      else
        inner_acc
      end
    end)
  end

  defp mxv_multiply(matrix, vector, multiply_fn, add_fn) do
    Enum.reduce(matrix.data.entries, %{}, fn {{i, k}, a_val}, acc ->
      case Map.get(vector.data.entries, k) do
        nil -> acc
        b_val -> accumulate_product(acc, i, a_val, b_val, multiply_fn, add_fn)
      end
    end)
  end

  defp vxm_multiply(vector, matrix, multiply_fn, add_fn) do
    Enum.reduce(vector.data.entries, %{}, fn {k, v_val}, acc ->
      vxm_row(k, v_val, matrix, multiply_fn, add_fn, acc)
    end)
  end

  defp vxm_row(k, v_val, matrix, multiply_fn, add_fn, acc) do
    Enum.reduce(matrix.data.entries, acc, fn {{k2, j}, m_val}, inner_acc ->
      if k == k2 do
        accumulate_product(inner_acc, j, v_val, m_val, multiply_fn, add_fn)
      else
        inner_acc
      end
    end)
  end

  defp accumulate_product(acc, key, a_val, b_val, multiply_fn, add_fn) do
    product = apply_op(multiply_fn, a_val, b_val)
    Map.update(acc, key, product, fn existing -> apply_op(add_fn, existing, product) end)
  end

  defp default_value(:bool), do: false
  defp default_value(:fp32), do: 0.0
  defp default_value(:fp64), do: 0.0
  defp default_value(_), do: 0

  #############################################################################
  # Container manipulation callbacks
  #############################################################################

  @impl GraphBLAS.Backend
  def matrix_set(
        %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: data},
        row,
        col,
        value
      ) do
    with :ok <- validate_index(row, nrows),
         :ok <- validate_index(col, ncols) do
      updated = Map.put(data.entries, {row, col}, value)

      {:ok,
       %Matrix{
         shape: {nrows, ncols},
         type: type,
         backend: __MODULE__,
         data: %{data | entries: updated}
       }}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_extract(
        %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: data},
        row,
        col
      ) do
    with :ok <- validate_index(row, nrows),
         :ok <- validate_index(col, ncols) do
      {:ok, Map.get(data.entries, {row, col}, default_value(type))}
    end
  end

  @impl GraphBLAS.Backend
  def matrix_dup(%Matrix{} = matrix) do
    {:ok,
     %Matrix{
       matrix
       | backend: __MODULE__,
         data: %{matrix.data | entries: Map.new(matrix.data.entries)}
     }}
  end

  @impl GraphBLAS.Backend
  def vector_set(%Vector{size: size, type: type, backend: __MODULE__, data: data}, index, value) do
    with :ok <- validate_index(index, size) do
      updated = Map.put(data.entries, index, value)

      {:ok,
       %Vector{size: size, type: type, backend: __MODULE__, data: %{data | entries: updated}}}
    end
  end

  @impl GraphBLAS.Backend
  def vector_extract(%Vector{size: size, type: type, backend: __MODULE__, data: data}, index) do
    with :ok <- validate_index(index, size) do
      {:ok, Map.get(data.entries, index, default_value(type))}
    end
  end

  @impl GraphBLAS.Backend
  def vector_dup(%Vector{} = vector) do
    {:ok,
     %Vector{
       vector
       | backend: __MODULE__,
         data: %{vector.data | entries: Map.new(vector.data.entries)}
     }}
  end

  #############################################################################
  # Mask and descriptor helpers
  #############################################################################

  defp validate_index(idx, max) when is_integer(idx) and idx >= 0 and idx < max, do: :ok
  defp validate_index(idx, max), do: Error.error({:index_out_of_bounds, {idx, max}})

  defp apply_matrix_mask(entries, opts, _nrows, _ncols) do
    case Keyword.get(opts, :mask) do
      nil ->
        entries

      %Mask{source: %Matrix{data: mask_data}, complement: complement?} ->
        mask_positions = get_matrix_mask_positions(mask_data, get_mask_mode(opts))

        entries
        |> Enum.filter(&in_mask_positions?(&1, mask_positions, complement?))
        |> Map.new()

      %Mask{source: %Vector{}} ->
        Error.error({:mask_type_mismatch, :vector, :matrix})

      _ ->
        entries
    end
  end

  defp apply_vector_mask(entries, opts, _size) do
    case Keyword.get(opts, :mask) do
      nil ->
        entries

      %Mask{source: %Vector{data: mask_data}, complement: complement?} ->
        mask_positions = get_vector_mask_positions(mask_data, get_mask_mode(opts))

        entries
        |> Enum.filter(&in_mask_positions?(&1, mask_positions, complement?))
        |> Map.new()

      %Mask{source: %Matrix{}} ->
        Error.error({:mask_type_mismatch, :matrix, :vector})

      _ ->
        entries
    end
  end

  defp in_mask_positions?({{r, c}, _v}, mask_positions, complement?) do
    in_mask = MapSet.member?(mask_positions, {r, c})
    if complement?, do: not in_mask, else: in_mask
  end

  defp in_mask_positions?({idx, _v}, mask_positions, complement?) do
    in_mask = MapSet.member?(mask_positions, idx)
    if complement?, do: not in_mask, else: in_mask
  end

  defp get_mask_mode(opts) do
    case Keyword.get(opts, :descriptor) do
      %Descriptor{mask: :value} -> :value
      _ -> :structural
    end
  end

  defp get_matrix_mask_positions(mask_data, :structural) do
    mask_data.entries |> Map.keys() |> MapSet.new()
  end

  defp get_matrix_mask_positions(mask_data, :value) do
    mask_data.entries
    |> Enum.filter(fn {_k, v} -> v != false and v != 0 and v != 0.0 end)
    |> Enum.map(fn {k, _v} -> k end)
    |> MapSet.new()
  end

  defp get_vector_mask_positions(mask_data, :structural) do
    mask_data.entries |> Map.keys() |> MapSet.new()
  end

  defp get_vector_mask_positions(mask_data, :value) do
    mask_data.entries
    |> Enum.filter(fn {_k, v} -> v != false and v != 0 and v != 0.0 end)
    |> Enum.map(fn {k, _v} -> k end)
    |> MapSet.new()
  end

  defp apply_descriptor_inputs(a, b, opts) do
    desc = Keyword.get(opts, :descriptor)

    a =
      if is_struct(desc, Descriptor) and desc.inp0_transpose == :transpose and a != nil do
        {:ok, t} = matrix_transpose(a, [])
        t
      else
        a
      end

    b =
      if is_struct(desc, Descriptor) and desc.inp1_transpose == :transpose and b != nil do
        {:ok, t} = matrix_transpose(b, [])
        t
      else
        b
      end

    {a, b}
  end
end
