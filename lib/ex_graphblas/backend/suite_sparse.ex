defmodule GraphBLAS.Backend.SuiteSparse do
  @moduledoc false

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

      case GraphBLAS.Native.matrix_new(nrows, ncols, code) do
        ptr when is_integer(ptr) ->
          {:ok,
           %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_from_coo(nrows, ncols, entries, type, _opts) do
    with :ok <- validate_type(type),
         :ok <- validate_dimensions(nrows, ncols) do
      code = type_to_code(type)

      case GraphBLAS.Native.matrix_new(nrows, ncols, code) do
        ptr when is_integer(ptr) ->
          build_matrix_from_coo(ptr, nrows, ncols, entries, type)

        {:error, reason} ->
          Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_nvals(%Matrix{data: %{ptr: ptr}}) do
    case GraphBLAS.Native.matrix_nvals(ptr) do
      n when is_integer(n) -> {:ok, n}
      {:error, reason} -> Error.error({:backend_error, __MODULE__, reason})
    end
  end

  @impl GraphBLAS.Backend
  def matrix_shape(%Matrix{shape: shape}), do: {:ok, shape}

  @impl GraphBLAS.Backend
  def matrix_type(%Matrix{type: type}), do: {:ok, type}

  @impl GraphBLAS.Backend
  def matrix_to_coo(%Matrix{type: type, data: %{ptr: ptr}}) do
    case GraphBLAS.Native.matrix_nvals(ptr) do
      n when is_integer(n) ->
        extract_result =
          case type do
            :int64 -> GraphBLAS.Native.matrix_extract_tuples_int64(ptr, n)
            :fp64 -> GraphBLAS.Native.matrix_extract_tuples_fp64(ptr, n)
            :bool -> GraphBLAS.Native.matrix_extract_tuples_bool(ptr, n)
          end

        case extract_result do
          %{rows: rows, cols: cols, vals: vals, actual_nvals: _} ->
            {:ok, Enum.zip_with([rows, cols, vals], fn [r, c, v] -> {r, c, v} end)}

          {:error, reason} ->
            Error.error({:backend_error, __MODULE__, reason})
        end

      {:error, reason} ->
        Error.error({:backend_error, __MODULE__, reason})
    end
  end

  @impl GraphBLAS.Backend
  def matrix_mxm(%Matrix{} = a, %Matrix{} = b, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      semiring_code = semiring_to_code(sr)

      desc = Keyword.get(opts, :descriptor)
      {a_ptr, _a} = maybe_transpose_inp0(a, desc)
      {b_ptr, _b} = maybe_transpose_inp1(b, desc)

      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      # Only build descriptor for mask/output fields, not transposition
      desc_ptr = build_descriptor_ptr(opts, mask_comp, skip_transpose: true)

      case GraphBLAS.Native.matrix_mxm(a_ptr, b_ptr, semiring_code, mask_ptr, desc_ptr) do
        ptr when is_integer(ptr) ->
          cleanup_descriptor(desc_ptr)
          nrows = GraphBLAS.Native.matrix_nrows(ptr)
          ncols = GraphBLAS.Native.matrix_ncols(ptr)

          {:ok,
           %Matrix{shape: {nrows, ncols}, type: sr.type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_mxv(%Matrix{} = matrix, %Vector{data: %{ptr: v_ptr}}, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      semiring_code = semiring_to_code(sr)

      desc = Keyword.get(opts, :descriptor)
      {m_ptr, _matrix} = maybe_transpose_inp0(matrix, desc)

      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp, skip_transpose: true)

      case GraphBLAS.Native.matrix_mxv(m_ptr, v_ptr, semiring_code, mask_ptr, desc_ptr) do
        ptr when is_integer(ptr) ->
          cleanup_descriptor(desc_ptr)
          size = GraphBLAS.Native.vector_size(ptr)
          {:ok, %Vector{size: size, type: sr.type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, reason})
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

      case GraphBLAS.Native.matrix_ewise_add(a_ptr, b_ptr, monoid_code, mask_ptr, desc_ptr) do
        ptr when is_integer(ptr) ->
          cleanup_descriptor(desc_ptr)
          {:ok, %Matrix{shape: a.shape, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, reason})
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

      case GraphBLAS.Native.matrix_ewise_mult(a_ptr, b_ptr, monoid_code, mask_ptr, desc_ptr) do
        ptr when is_integer(ptr) ->
          cleanup_descriptor(desc_ptr)
          {:ok, %Matrix{shape: a.shape, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, reason})
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

      case GraphBLAS.Native.matrix_reduce_to_vector(ptr, monoid_code, mask_ptr, desc_ptr) do
        v_ptr when is_integer(v_ptr) ->
          cleanup_descriptor(desc_ptr)
          size = GraphBLAS.Native.vector_size(v_ptr)
          {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: v_ptr}}}

        {:error, reason} ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def matrix_transpose(%Matrix{data: %{ptr: ptr}, type: type}, opts) do
    mask_ptr = extract_mask_ptr(opts)
    mask_comp = mask_is_complement?(opts)
    desc_ptr = build_descriptor_ptr(opts, mask_comp)

    case GraphBLAS.Native.matrix_transpose(ptr, mask_ptr, desc_ptr) do
      t_ptr when is_integer(t_ptr) ->
        cleanup_descriptor(desc_ptr)
        nrows = GraphBLAS.Native.matrix_nrows(t_ptr)
        ncols = GraphBLAS.Native.matrix_ncols(t_ptr)

        {:ok,
         %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: t_ptr}}}

      {:error, reason} ->
        cleanup_descriptor(desc_ptr)
        Error.error({:backend_error, __MODULE__, reason})
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
      result =
        case type do
          :int64 -> GraphBLAS.Native.matrix_set_int64(ptr, row, col, value)
          :fp64 -> GraphBLAS.Native.matrix_set_fp64(ptr, row, col, value)
          :bool -> GraphBLAS.Native.matrix_set_bool(ptr, row, col, value)
        end

      case result do
        :ok ->
          {:ok,
           %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          Error.error({:backend_error, __MODULE__, reason})
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
      result =
        case type do
          :int64 -> GraphBLAS.Native.matrix_extract_int64(ptr, row, col)
          :fp64 -> GraphBLAS.Native.matrix_extract_fp64(ptr, row, col)
          :bool -> GraphBLAS.Native.matrix_extract_bool(ptr, row, col)
        end

      case result do
        value when is_integer(value) -> {:ok, value}
        value when is_float(value) -> {:ok, value}
        value when is_boolean(value) -> {:ok, value}
        {:error, reason} -> Error.error({:backend_error, __MODULE__, reason})
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
    case GraphBLAS.Native.matrix_dup(ptr) do
      new_ptr when is_integer(new_ptr) ->
        {:ok,
         %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: new_ptr}}}

      {:error, reason} ->
        Error.error({:backend_error, __MODULE__, reason})
    end
  end

  #############################################################################
  # Vector callbacks
  #############################################################################

  @impl GraphBLAS.Backend
  def vector_new(size, type, _opts) do
    with :ok <- validate_type(type) do
      code = type_to_code(type)

      case GraphBLAS.Native.vector_new(size, code) do
        ptr when is_integer(ptr) ->
          {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_from_entries(size, entries, type, _opts) do
    with :ok <- validate_type(type) do
      code = type_to_code(type)

      case GraphBLAS.Native.vector_new(size, code) do
        ptr when is_integer(ptr) ->
          build_vector_from_entries(ptr, size, entries, type)

        {:error, reason} ->
          Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_nvals(%Vector{data: %{ptr: ptr}}) do
    case GraphBLAS.Native.vector_nvals(ptr) do
      n when is_integer(n) -> {:ok, n}
      {:error, reason} -> Error.error({:backend_error, __MODULE__, reason})
    end
  end

  @impl GraphBLAS.Backend
  def vector_size(%Vector{size: size}), do: {:ok, size}

  @impl GraphBLAS.Backend
  def vector_type(%Vector{type: type}), do: {:ok, type}

  @impl GraphBLAS.Backend
  def vector_to_entries(%Vector{type: type, data: %{ptr: ptr}}) do
    case GraphBLAS.Native.vector_nvals(ptr) do
      n when is_integer(n) ->
        extract_result =
          case type do
            :int64 -> GraphBLAS.Native.vector_extract_tuples_int64(ptr, n)
            :fp64 -> GraphBLAS.Native.vector_extract_tuples_fp64(ptr, n)
            :bool -> GraphBLAS.Native.vector_extract_tuples_bool(ptr, n)
          end

        case extract_result do
          %{indices: indices, vals: vals, actual_nvals: _} ->
            {:ok, Enum.zip_with([indices, vals], fn [i, v] -> {i, v} end)}

          {:error, reason} ->
            Error.error({:backend_error, __MODULE__, reason})
        end

      {:error, reason} ->
        Error.error({:backend_error, __MODULE__, reason})
    end
  end

  @impl GraphBLAS.Backend
  def vector_vxm(%Vector{data: %{ptr: v_ptr}}, %Matrix{} = matrix, semiring, opts) do
    with {:ok, sr} <- resolve_semiring(semiring) do
      semiring_code = semiring_to_code(sr)

      desc = Keyword.get(opts, :descriptor)
      {m_ptr, _matrix} = maybe_transpose_inp1(matrix, desc)

      mask_ptr = extract_mask_ptr(opts)
      mask_comp = mask_is_complement?(opts)
      desc_ptr = build_descriptor_ptr(opts, mask_comp, skip_transpose: true)

      case GraphBLAS.Native.vector_vxm(v_ptr, m_ptr, semiring_code, mask_ptr, desc_ptr) do
        ptr when is_integer(ptr) ->
          cleanup_descriptor(desc_ptr)
          size = GraphBLAS.Native.vector_size(ptr)
          {:ok, %Vector{size: size, type: sr.type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, reason})
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

      case GraphBLAS.Native.vector_ewise_add(a_ptr, b_ptr, monoid_code, mask_ptr, desc_ptr) do
        ptr when is_integer(ptr) ->
          cleanup_descriptor(desc_ptr)
          {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, reason})
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

      case GraphBLAS.Native.vector_ewise_mult(a_ptr, b_ptr, monoid_code, mask_ptr, desc_ptr) do
        ptr when is_integer(ptr) ->
          cleanup_descriptor(desc_ptr)
          {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          cleanup_descriptor(desc_ptr)
          Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_reduce(%Vector{type: type, data: %{ptr: ptr}}, monoid, _opts) do
    with {:ok, m} <- resolve_monoid(monoid) do
      monoid_code = monoid_to_code(m)

      result =
        case type do
          :int64 -> GraphBLAS.Native.vector_reduce_to_scalar_int64(ptr, monoid_code)
          :fp64 -> GraphBLAS.Native.vector_reduce_to_scalar_fp64(ptr, monoid_code)
          :bool -> GraphBLAS.Native.vector_reduce_to_scalar_bool(ptr, monoid_code)
        end

      case result do
        value when is_integer(value) -> {:ok, %Scalar{type: type, value: value}}
        value when is_float(value) -> {:ok, %Scalar{type: type, value: value}}
        value when is_boolean(value) -> {:ok, %Scalar{type: type, value: value}}
        {:error, reason} -> Error.error({:backend_error, __MODULE__, reason})
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
      result =
        case type do
          :int64 -> GraphBLAS.Native.vector_set_int64(ptr, index, value)
          :fp64 -> GraphBLAS.Native.vector_set_fp64(ptr, index, value)
          :bool -> GraphBLAS.Native.vector_set_bool(ptr, index, value)
        end

      case result do
        :ok ->
          {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

        {:error, reason} ->
          Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_extract(
        %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}},
        index
      ) do
    with :ok <- validate_index(index, size) do
      result =
        case type do
          :int64 -> GraphBLAS.Native.vector_extract_int64(ptr, index)
          :fp64 -> GraphBLAS.Native.vector_extract_fp64(ptr, index)
          :bool -> GraphBLAS.Native.vector_extract_bool(ptr, index)
        end

      case result do
        value when is_integer(value) -> {:ok, value}
        value when is_float(value) -> {:ok, value}
        value when is_boolean(value) -> {:ok, value}
        {:error, reason} -> Error.error({:backend_error, __MODULE__, reason})
      end
    end
  end

  @impl GraphBLAS.Backend
  def vector_dup(%Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}) do
    case GraphBLAS.Native.vector_dup(ptr) do
      new_ptr when is_integer(new_ptr) ->
        {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: new_ptr}}}

      {:error, reason} ->
        Error.error({:backend_error, __MODULE__, reason})
    end
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
    GraphBLAS.Native.matrix_free(ptr)
  end

  @doc """
  Releases the SuiteSparse:GraphBLAS resources for a vector.

  After calling this function, the vector struct is no longer valid and
  must not be used.
  """
  @spec vector_free(Vector.t()) :: :ok
  def vector_free(%Vector{data: %{ptr: ptr}}) do
    GraphBLAS.Native.vector_free(ptr)
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
  defp validate_index(idx, max), do: Error.error({:index_out_of_bounds, {idx, max}})

  defp maybe_transpose_inp0(%Matrix{data: %{ptr: ptr}} = m, desc) do
    if is_struct(desc, GraphBLAS.Descriptor) and desc.inp0_transpose == :transpose do
      case matrix_transpose(m, []) do
        {:ok, %Matrix{data: %{ptr: t_ptr}} = t} ->
          {t_ptr, t}

        {:error, _} = err ->
          Error.error(err)
      end
    else
      {ptr, m}
    end
  end

  defp maybe_transpose_inp1(%Matrix{data: %{ptr: ptr}} = m, desc) do
    if is_struct(desc, GraphBLAS.Descriptor) and desc.inp1_transpose == :transpose do
      case matrix_transpose(m, []) do
        {:ok, %Matrix{data: %{ptr: t_ptr}} = t} ->
          {t_ptr, t}

        {:error, _} = err ->
          Error.error(err)
      end
    else
      {ptr, m}
    end
  end

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
      case GraphBLAS.Native.descriptor_create(
             inp0_tran,
             inp1_tran,
             output_replace,
             mask_complement,
             mask_structural
           ) do
        ptr when is_integer(ptr) -> ptr
        {:error, reason} -> Error.error({:backend_error, __MODULE__, reason})
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
    if GraphBLAS.Native.descriptor_is_custom(ptr) do
      GraphBLAS.Native.descriptor_free(ptr)
    end
  end

  defp build_matrix_from_coo(ptr, nrows, ncols, entries, type) do
    {rows, cols, vals} = unzip_coo(entries, type)

    build_result =
      case type do
        :int64 -> GraphBLAS.Native.matrix_build_int64(ptr, rows, cols, vals, length(entries))
        :fp64 -> GraphBLAS.Native.matrix_build_fp64(ptr, rows, cols, vals, length(entries))
        :bool -> GraphBLAS.Native.matrix_build_bool(ptr, rows, cols, vals, length(entries))
      end

    case build_result do
      :ok ->
        {:ok, %Matrix{shape: {nrows, ncols}, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

      {:error, reason} ->
        GraphBLAS.Native.matrix_free(ptr)
        Error.error({:backend_error, __MODULE__, reason})
    end
  end

  defp build_vector_from_entries(ptr, size, entries, type) do
    {indices, vals} = unzip_vector_entries(entries, type)

    build_result =
      case type do
        :int64 -> GraphBLAS.Native.vector_build_int64(ptr, indices, vals, length(entries))
        :fp64 -> GraphBLAS.Native.vector_build_fp64(ptr, indices, vals, length(entries))
        :bool -> GraphBLAS.Native.vector_build_bool(ptr, indices, vals, length(entries))
      end

    case build_result do
      :ok ->
        {:ok, %Vector{size: size, type: type, backend: __MODULE__, data: %{ptr: ptr}}}

      {:error, reason} ->
        GraphBLAS.Native.vector_free(ptr)
        Error.error({:backend_error, __MODULE__, reason})
    end
  end
end
