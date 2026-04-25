defmodule GraphBLAS.Backend.SuiteSparse do
  @moduledoc """
  SuiteSparse:GraphBLAS-backed implementation of the `GraphBLAS.Backend` behaviour.

  This backend delegates all compute-heavy operations to the native
  SuiteSparse:GraphBLAS C library via the `GraphBLAS.Native` NIF module.

  It is intended for production use once SuiteSparse is installed and
  correctly configured. For development and testing, the
  `GraphBLAS.Backend.Elixir` backend remains the safer default.
  """

  @behaviour GraphBLAS.Backend

  alias GraphBLAS.{Error, Mask, Matrix, Monoid, Scalar, Semiring, Vector}

  # Type codes matching native.ex
  @type_bool 1
  @type_int64 8
  @type_fp64 11

  # Semiring codes matching native.ex
  @semiring_plus_times 1
  @semiring_plus_times_fp64 2
  @semiring_plus_min 3
  @semiring_plus_min_fp64 4
  @semiring_max_plus 5
  @semiring_max_plus_fp64 6
  @semiring_max_min 7
  @semiring_max_min_fp64 8
  @semiring_lor_land 9
  @semiring_land_lor 10
  @semiring_min_plus 11
  @semiring_min_plus_fp64 12

  # Monoid codes matching native.ex
  @monoid_plus 1
  @monoid_plus_fp64 2
  @monoid_times 3
  @monoid_times_fp64 4
  @monoid_min 5
  @monoid_min_fp64 6
  @monoid_max 7
  @monoid_max_fp64 8
  @monoid_land 9
  @monoid_lor 10
  @monoid_lxor 11

  @supported_types [:int64, :fp64, :bool]

  #############################################################################
  # Matrix callbacks
  #############################################################################

  @impl GraphBLAS.Backend
  def matrix_new(nrows, ncols, type, _opts) do
    with :ok <- validate_type(type),
         :ok <- validate_dimensions(nrows, ncols) do
      code = type_to_code(type)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.matrix_new(nrows, ncols, code)
        {:ok, %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_from_coo(nrows, ncols, entries, type, _opts) do
    with :ok <- validate_type(type),
         :ok <- validate_dimensions(nrows, ncols) do
      code = type_to_code(type)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.matrix_new(nrows, ncols, code)
        build_matrix_from_coo(ptr, nrows, ncols, entries, type)
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_nvals(%Matrix{data: %{ptr: ptr}}) do
    n = GraphBLAS.Native.SuiteSparse.matrix_nvals(ptr)
    {:ok, n}
  rescue
    e -> Error.error({:backend_error, __MODULE__, e})
  end

  @impl GraphBLAS.Backend
  def matrix_shape(%Matrix{shape: shape}), do: {:ok, shape}

  @impl GraphBLAS.Backend
  def matrix_type(%Matrix{type: type}), do: {:ok, type}

  @impl GraphBLAS.Backend
  def matrix_to_coo(%Matrix{type: type, data: %{ptr: ptr}}) do
    n = GraphBLAS.Native.SuiteSparse.matrix_nvals(ptr)

    extract_result =
      case type do
        :int64 -> GraphBLAS.Native.SuiteSparse.matrix_extract_tuples_int64(ptr, n)
        :fp64 -> GraphBLAS.Native.SuiteSparse.matrix_extract_tuples_fp64(ptr, n)
        :bool -> GraphBLAS.Native.SuiteSparse.matrix_extract_tuples_bool(ptr, n)
      end

    %{rows: rows, cols: cols, vals: vals, actual_nvals: _} = extract_result
    {:ok, Enum.zip_with([rows, cols, vals], fn [r, c, v] -> {r, c, v} end)}
  rescue
    e -> Error.error({:backend_error, __MODULE__, e})
  end

  @impl GraphBLAS.Backend
  def matrix_mxm(%Matrix{} = a, %Matrix{} = b, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      semiring_code = semiring_to_code(sr)

      desc = Keyword.get(opts, :descriptor)
      {a_ptr, a_transposed} = maybe_transpose_inp0(a, desc)
      {b_ptr, b_transposed} = maybe_transpose_inp1(b, desc)

      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp, skip_transpose: true)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.matrix_mxm(a_ptr, b_ptr, semiring_code, mask_ptr, desc_ptr)
        cleanup_descriptor(desc_ptr)
        nrows = GraphBLAS.Native.SuiteSparse.matrix_nrows(ptr)
        ncols = GraphBLAS.Native.SuiteSparse.matrix_ncols(ptr)

        {:ok,
         %Matrix{shape: {nrows, ncols}, type: sr.type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, e})
      after
        maybe_free_transposed(a_ptr, a_transposed)
        maybe_free_transposed(b_ptr, b_transposed)
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_mxv(%Matrix{} = matrix, %Vector{data: %{ptr: v_ptr}}, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      semiring_code = semiring_to_code(sr)

      desc = Keyword.get(opts, :descriptor)
      {m_ptr, m_transposed} = maybe_transpose_inp0(matrix, desc)

      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp, skip_transpose: true)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.matrix_mxv(m_ptr, v_ptr, semiring_code, mask_ptr, desc_ptr)
        cleanup_descriptor(desc_ptr)
        size = GraphBLAS.Native.SuiteSparse.vector_size(ptr)
        {:ok, %Vector{size: size, type: sr.type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, e})
      after
        maybe_free_transposed(m_ptr, m_transposed)
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_ewise_add(
        %Matrix{data: %{ptr: a_ptr}, type: type} = a,
        %Matrix{data: %{ptr: b_ptr}},
        monoid,
        opts
      ) do
    with {:ok, m} <- resolve_monoid(monoid) do
      monoid_code = monoid_to_code(m)
      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.matrix_ewise_add(a_ptr, b_ptr, monoid_code, mask_ptr, desc_ptr)
        cleanup_descriptor(desc_ptr)
        {:ok, %Matrix{shape: a.shape, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_ewise_mult(
        %Matrix{data: %{ptr: a_ptr}, type: type} = a,
        %Matrix{data: %{ptr: b_ptr}},
        monoid,
        opts
      ) do
    with {:ok, m} <- resolve_monoid(monoid) do
      monoid_code = monoid_to_code(m)
      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.matrix_ewise_mult(a_ptr, b_ptr, monoid_code, mask_ptr, desc_ptr)
        cleanup_descriptor(desc_ptr)
        {:ok, %Matrix{shape: a.shape, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_reduce(%Matrix{data: %{ptr: ptr}, type: type}, monoid, opts) do
    with {:ok, m} <- resolve_monoid(monoid) do
      monoid_code = monoid_to_code(m)
      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp)

      try do
        v_ptr = GraphBLAS.Native.SuiteSparse.matrix_reduce_to_vector(ptr, monoid_code, mask_ptr, desc_ptr)
        cleanup_descriptor(desc_ptr)
        size = GraphBLAS.Native.SuiteSparse.vector_size(v_ptr)
        {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: v_ptr}}}
      rescue
        e ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_transpose(%Matrix{data: %{ptr: ptr}, type: type}, opts) do
    mask_ptr = extract_mask_ptr(opts)
    mask_comp = mask_is_complement?(opts)
    desc_ptr = build_descriptor_ptr(opts, mask_comp)

    try do
      t_ptr = GraphBLAS.Native.SuiteSparse.matrix_transpose(ptr, mask_ptr, desc_ptr)
      cleanup_descriptor(desc_ptr)
      nrows = GraphBLAS.Native.SuiteSparse.matrix_nrows(t_ptr)
      ncols = GraphBLAS.Native.SuiteSparse.matrix_ncols(t_ptr)
      {:ok, %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: t_ptr}}}
    rescue
      e ->
        cleanup_descriptor(desc_ptr)
        Error.error({:backend_error, __MODULE__, e})
    end
  end

  @impl GraphBLAS.Backend
  def matrix_to_dense(%Matrix{type: type, shape: {nrows, ncols}} = matrix) do
    case matrix_to_coo(matrix) do
      {:ok, entries} ->
        default = default_value(type)
        dense = List.duplicate(List.duplicate(default, ncols), nrows)

        filled =
          Enum.reduce(entries, dense, fn {r, c, v}, acc ->
            row = Enum.at(acc, r)
            updated_row = List.replace_at(row, c, v)
            List.replace_at(acc, r, updated_row)
          end)

        {:ok, filled}

      {:error, _} = err ->
        err
    end
  end

  @impl GraphBLAS.Backend
  def matrix_set(
        %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: ptr}},
        row,
        col,
        value
      ) do
    with :ok <- validate_index(row, nrows),
         :ok <- validate_index(col, ncols) do
      try do
        case type do
          :int64 -> GraphBLAS.Native.SuiteSparse.matrix_set_int64(ptr, row, col, value)
          :fp64 -> GraphBLAS.Native.SuiteSparse.matrix_set_fp64(ptr, row, col, value)
          :bool -> GraphBLAS.Native.SuiteSparse.matrix_set_bool(ptr, row, col, value)
        end

        {:ok, %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_extract(
        %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: ptr}},
        row,
        col
      ) do
    with :ok <- validate_index(row, nrows),
         :ok <- validate_index(col, ncols) do
      try do
        value =
          case type do
            :int64 -> GraphBLAS.Native.SuiteSparse.matrix_extract_int64(ptr, row, col)
            :fp64 -> GraphBLAS.Native.SuiteSparse.matrix_extract_fp64(ptr, row, col)
            :bool -> GraphBLAS.Native.SuiteSparse.matrix_extract_bool(ptr, row, col)
          end

        {:ok, value}
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_dup(%Matrix{
        shape: {nrows, ncols},
        type: type,
        backend: __MODULE__,
        data: %{ptr: ptr}
      }) do
    new_ptr = GraphBLAS.Native.SuiteSparse.matrix_dup(ptr)

    {:ok, %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: new_ptr}}}
  rescue
    e -> Error.error({:backend_error, __MODULE__, e})
  end

  #############################################################################
  # Vector callbacks
  #############################################################################

  @impl GraphBLAS.Backend
  def vector_new(size, type, _opts) do
    with :ok <- validate_type(type) do
      code = type_to_code(type)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.vector_new(size, code)
        {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_from_entries(size, entries, type, _opts) do
    with :ok <- validate_type(type) do
      code = type_to_code(type)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.vector_new(size, code)
        build_vector_from_entries(ptr, size, entries, type)
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_nvals(%Vector{data: %{ptr: ptr}}) do
    n = GraphBLAS.Native.SuiteSparse.vector_nvals(ptr)
    {:ok, n}
  rescue
    e -> Error.error({:backend_error, __MODULE__, e})
  end

  @impl GraphBLAS.Backend
  def vector_size(%Vector{size: size}), do: {:ok, size}

  @impl GraphBLAS.Backend
  def vector_type(%Vector{type: type}), do: {:ok, type}

  @impl GraphBLAS.Backend
  def vector_to_entries(%Vector{type: type, data: %{ptr: ptr}}) do
    n = GraphBLAS.Native.SuiteSparse.vector_nvals(ptr)

    extract_result =
      case type do
        :int64 -> GraphBLAS.Native.SuiteSparse.vector_extract_tuples_int64(ptr, n)
        :fp64 -> GraphBLAS.Native.SuiteSparse.vector_extract_tuples_fp64(ptr, n)
        :bool -> GraphBLAS.Native.SuiteSparse.vector_extract_tuples_bool(ptr, n)
      end

    %{indices: indices, vals: vals, actual_nvals: _} = extract_result
    {:ok, Enum.zip_with([indices, vals], fn [i, v] -> {i, v} end)}
  rescue
    e -> Error.error({:backend_error, __MODULE__, e})
  end

  @impl GraphBLAS.Backend
  def vector_vxm(%Vector{data: %{ptr: v_ptr}}, %Matrix{} = matrix, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      semiring_code = semiring_to_code(sr)

      desc = Keyword.get(opts, :descriptor)
      {m_ptr, m_transposed} = maybe_transpose_inp1(matrix, desc)

      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp, skip_transpose: true)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.vector_vxm(v_ptr, m_ptr, semiring_code, mask_ptr, desc_ptr)
        cleanup_descriptor(desc_ptr)
        size = GraphBLAS.Native.SuiteSparse.vector_size(ptr)
        {:ok, %Vector{size: size, type: sr.type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, e})
      after
        maybe_free_transposed(m_ptr, m_transposed)
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_ewise_add(
        %Vector{data: %{ptr: a_ptr}, size: size, type: type},
        %Vector{data: %{ptr: b_ptr}},
        monoid,
        opts
      ) do
    with {:ok, m} <- resolve_monoid(monoid) do
      monoid_code = monoid_to_code(m)
      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.vector_ewise_add(a_ptr, b_ptr, monoid_code, mask_ptr, desc_ptr)
        cleanup_descriptor(desc_ptr)
        {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_ewise_mult(
        %Vector{data: %{ptr: a_ptr}, size: size, type: type},
        %Vector{data: %{ptr: b_ptr}},
        monoid,
        opts
      ) do
    with {:ok, m} <- resolve_monoid(monoid) do
      monoid_code = monoid_to_code(m)
      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp)

      try do
        ptr = GraphBLAS.Native.SuiteSparse.vector_ewise_mult(a_ptr, b_ptr, monoid_code, mask_ptr, desc_ptr)
        cleanup_descriptor(desc_ptr)
        {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_reduce(%Vector{type: type, data: %{ptr: ptr}}, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid) do
      monoid_code = monoid_to_code(m)

      try do
        value =
          case type do
            :int64 -> GraphBLAS.Native.SuiteSparse.vector_reduce_to_scalar_int64(ptr, monoid_code)
            :fp64 -> GraphBLAS.Native.SuiteSparse.vector_reduce_to_scalar_fp64(ptr, monoid_code)
            :bool -> GraphBLAS.Native.SuiteSparse.vector_reduce_to_scalar_bool(ptr, monoid_code)
          end

        {:ok, %Scalar{type: type, value: value}}
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_to_list(%Vector{type: type, size: size} = vector) do
    case vector_to_entries(vector) do
      {:ok, entries} ->
        default = default_value(type)
        list = List.duplicate(default, size)

        list =
          Enum.reduce(entries, list, fn {idx, val}, acc ->
            List.replace_at(acc, idx, val)
          end)

        {:ok, list}

      {:error, _} = err ->
        err
    end
  end

  @impl GraphBLAS.Backend
  def vector_set(
        %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}},
        index,
        value
      ) do
    with :ok <- validate_index(index, size) do
      try do
        case type do
          :int64 -> GraphBLAS.Native.SuiteSparse.vector_set_int64(ptr, index, value)
          :fp64 -> GraphBLAS.Native.SuiteSparse.vector_set_fp64(ptr, index, value)
          :bool -> GraphBLAS.Native.SuiteSparse.vector_set_bool(ptr, index, value)
        end

        {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_extract(
        %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}},
        index
      ) do
    with :ok <- validate_index(index, size) do
      try do
        value =
          case type do
            :int64 -> GraphBLAS.Native.SuiteSparse.vector_extract_int64(ptr, index)
            :fp64 -> GraphBLAS.Native.SuiteSparse.vector_extract_fp64(ptr, index)
            :bool -> GraphBLAS.Native.SuiteSparse.vector_extract_bool(ptr, index)
          end

        {:ok, value}
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_dup(%Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}) do
    new_ptr = GraphBLAS.Native.SuiteSparse.vector_dup(ptr)
    {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: new_ptr}}}
  rescue
    e -> Error.error({:backend_error, __MODULE__, e})
  end

  #############################################################################
  # Explicit memory management
  #############################################################################

  @doc """
  Releases the SuiteSparse:GraphBLAS resources for a matrix.

  After calling this function, the matrix struct is no longer valid and
  must not be used. This is required because C pointers are stored as
  opaque integers in Elixir structs and are not automatically garbage
  collected by the BEAM.
  """
  @spec matrix_free(Matrix.t()) :: :ok
  def matrix_free(%Matrix{data: %{ptr: ptr}}) do
    GraphBLAS.Native.SuiteSparse.matrix_free(ptr)
  end

  @doc """
  Releases the SuiteSparse:GraphBLAS resources for a vector.

  After calling this function, the vector struct is no longer valid and
  must not be used.
  """
  @spec vector_free(Vector.t()) :: :ok
  def vector_free(%Vector{data: %{ptr: ptr}}) do
    GraphBLAS.Native.SuiteSparse.vector_free(ptr)
  end

  #############################################################################
  # Private helpers
  #############################################################################

  defp validate_type(type) when type in @supported_types, do: :ok
  defp validate_type(type), do: Error.error({:unsupported_type, type})

  defp validate_dimensions(nrows, ncols) when nrows >= 0 and ncols >= 0, do: :ok

  defp validate_dimensions(nrows, ncols) do
    Error.error({:invalid_argument, "dimensions must be non-negative, got {#{nrows}, #{ncols}}"})
  end

  defp type_to_code(:bool), do: @type_bool
  defp type_to_code(:int64), do: @type_int64
  defp type_to_code(:fp64), do: @type_fp64

  @semiring_codes %{
    plus_times: @semiring_plus_times,
    plus_times_fp64: @semiring_plus_times_fp64,
    plus_min: @semiring_plus_min,
    plus_min_fp64: @semiring_plus_min_fp64,
    max_plus: @semiring_max_plus,
    max_plus_fp64: @semiring_max_plus_fp64,
    max_min: @semiring_max_min,
    max_min_fp64: @semiring_max_min_fp64,
    lor_land: @semiring_lor_land,
    land_lor: @semiring_land_lor,
    min_plus: @semiring_min_plus,
    min_plus_fp64: @semiring_min_plus_fp64
  }

  @monoid_codes %{
    plus: @monoid_plus,
    plus_fp64: @monoid_plus_fp64,
    times: @monoid_times,
    times_fp64: @monoid_times_fp64,
    min: @monoid_min,
    min_fp64: @monoid_min_fp64,
    max: @monoid_max,
    max_fp64: @monoid_max_fp64,
    land: @monoid_land,
    lor: @monoid_lor,
    lxor: @monoid_lxor
  }

  defp semiring_to_code(%Semiring{name: name}), do: Map.fetch!(@semiring_codes, name)
  defp monoid_to_code(%Monoid{name: name}), do: Map.fetch!(@monoid_codes, name)

  defp resolve_semiring(name) when is_atom(name), do: Semiring.resolve(name)
  defp resolve_semiring(%Semiring{} = s), do: {:ok, s}

  defp resolve_monoid(name) when is_atom(name), do: Monoid.resolve(name)
  defp resolve_monoid(%Monoid{} = m), do: {:ok, m}

  defp unzip_coo(entries, _type) do
    rows = Enum.map(entries, fn {r, _c, _v} -> r end)
    cols = Enum.map(entries, fn {_r, c, _v} -> c end)
    vals = Enum.map(entries, fn {_r, _c, v} -> v end)
    {rows, cols, vals}
  end

  defp unzip_vector_entries(entries, _type) do
    indices = Enum.map(entries, fn {i, _v} -> i end)
    vals = Enum.map(entries, fn {_i, v} -> v end)
    {indices, vals}
  end

  defp default_value(:bool), do: false
  defp default_value(:fp64), do: 0.0
  defp default_value(_), do: 0

  defp validate_index(idx, max) when is_integer(idx) and idx >= 0 and idx < max, do: :ok
  defp validate_index(idx, max), do: Error.error({:index_out_of_bounds, idx, :index, max})

  # Returns {ptr, transposed?} where transposed? indicates the ptr must be freed by caller.
  defp maybe_transpose_inp0(%Matrix{data: %{ptr: ptr}} = m, desc) do
    if is_struct(desc, GraphBLAS.Descriptor) and desc.inp0_transpose == :transpose do
      case matrix_transpose(m, []) do
        {:ok, %Matrix{data: %{ptr: t_ptr}}} -> {t_ptr, true}
        {:error, _} = err -> err
      end
    else
      {ptr, false}
    end
  end

  defp maybe_transpose_inp1(%Matrix{data: %{ptr: ptr}} = m, desc) do
    if is_struct(desc, GraphBLAS.Descriptor) and desc.inp1_transpose == :transpose do
      case matrix_transpose(m, []) do
        {:ok, %Matrix{data: %{ptr: t_ptr}}} -> {t_ptr, true}
        {:error, _} = err -> err
      end
    else
      {ptr, false}
    end
  end

  defp maybe_free_transposed(ptr, true),
    do: GraphBLAS.Native.SuiteSparse.matrix_free(ptr)

  defp maybe_free_transposed(_ptr, false), do: :ok

  defp extract_mask_ptr(opts) do
    case Keyword.get(opts, :mask) do
      nil -> 0
      %Mask{source: %Matrix{data: %{ptr: ptr}}} -> ptr
      %Mask{source: %Vector{data: %{ptr: ptr}}} -> ptr
    end
  end

  defp mask_is_complement?(opts) do
    case Keyword.get(opts, :mask) do
      %Mask{complement: true} -> true
      _ -> false
    end
  end

  defp build_descriptor_ptr(opts, mask_complement, opts_overrides \\ []) do
    desc = Keyword.get(opts, :descriptor)
    skip_transpose = Keyword.get(opts_overrides, :skip_transpose, false)
    has_mask = Keyword.get(opts, :mask) != nil

    {inp0_tran, inp1_tran, output_replace, mask_structural} =
      resolve_descriptor_flags(desc, skip_transpose, has_mask, mask_complement)

    if inp0_tran or inp1_tran or output_replace or mask_complement or mask_structural do
      try do
        GraphBLAS.Native.SuiteSparse.descriptor_create(
          inp0_tran,
          inp1_tran,
          output_replace,
          mask_complement,
          mask_structural
        )
      rescue
        e -> Error.error({:backend_error, __MODULE__, e})
      end
    else
      0
    end
  end

  defp resolve_descriptor_flags(desc, skip_transpose, has_mask, _mask_complement) do
    desc_struct? = is_struct(desc, GraphBLAS.Descriptor)

    inp0_tran = not skip_transpose and desc_struct? and desc.inp0_transpose == :transpose
    inp1_tran = not skip_transpose and desc_struct? and desc.inp1_transpose == :transpose
    output_replace = desc_struct? and desc.output == :replace

    mask_mode = if desc_struct?, do: desc.mask, else: :structural
    mask_structural = has_mask and mask_mode == :structural

    {inp0_tran, inp1_tran, output_replace, mask_structural}
  end

  defp cleanup_descriptor(0), do: :ok

  defp cleanup_descriptor(ptr) when is_integer(ptr) and ptr != 0 do
    if GraphBLAS.Native.SuiteSparse.descriptor_is_custom(ptr) do
      GraphBLAS.Native.SuiteSparse.descriptor_free(ptr)
    end
  end

  defp build_matrix_from_coo(ptr, nrows, ncols, entries, type) do
    {rows, cols, vals} = unzip_coo(entries, type)

    try do
      case type do
        :int64 -> GraphBLAS.Native.SuiteSparse.matrix_build_int64(ptr, rows, cols, vals, length(entries))
        :fp64 -> GraphBLAS.Native.SuiteSparse.matrix_build_fp64(ptr, rows, cols, vals, length(entries))
        :bool -> GraphBLAS.Native.SuiteSparse.matrix_build_bool(ptr, rows, cols, vals, length(entries))
      end

      {:ok, %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
    rescue
      e ->
        GraphBLAS.Native.SuiteSparse.matrix_free(ptr)
        Error.error({:backend_error, __MODULE__, e})
    end
  end

  defp build_vector_from_entries(ptr, size, entries, type) do
    {indices, vals} = unzip_vector_entries(entries, type)

    try do
      case type do
        :int64 -> GraphBLAS.Native.SuiteSparse.vector_build_int64(ptr, indices, vals, length(entries))
        :fp64 -> GraphBLAS.Native.SuiteSparse.vector_build_fp64(ptr, indices, vals, length(entries))
        :bool -> GraphBLAS.Native.SuiteSparse.vector_build_bool(ptr, indices, vals, length(entries))
      end

      {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}
    rescue
      e ->
        GraphBLAS.Native.SuiteSparse.vector_free(ptr)
        Error.error({:backend_error, __MODULE__, e})
    end
  end
end
