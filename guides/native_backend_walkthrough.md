# Native Backend Walkthrough: How Elixir Talks to SuiteSparse

**Status: IMPLEMENTED**

## The boundary we are crossing

Phase 2 gave us a backend that runs entirely in the BEAM. Every operation is pure Elixir — flat maps, `Enum.reduce`, `Map.merge`. It is correct, inspectable, and slow.

Phase 3 crosses the BEAM-native boundary. When you call `GraphBLAS.Matrix.mxm(a, b, :plus_times, backend: GraphBLAS.Backend.SuiteSparse)`, the computation leaves the BEAM and enters the C world of SuiteSparse:GraphBLAS.

This walkthrough explains exactly what happens at that boundary, why it is safe, and how to reason about it.

## Your first native matrix multiplication

```elixir
# Create matrices using the SuiteSparse backend
{:ok, a} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 1}, {2, 0, 1}], :int64,
  backend: GraphBLAS.Backend.SuiteSparse
)
{:ok, b} = GraphBLAS.Matrix.from_coo(3, 3, [{0, 1, 1}, {1, 2, 1}, {2, 0, 1}], :int64,
  backend: GraphBLAS.Backend.SuiteSparse
)

# Multiply using SuiteSparse
{:ok, c} = GraphBLAS.Matrix.mxm(a, b, :plus_times,
  backend: GraphBLAS.Backend.SuiteSparse
)

# Inspect the result
{:ok, {3, 3}} = GraphBLAS.Matrix.shape(c)
{:ok, coo} = GraphBLAS.Matrix.to_coo(c)

# IMPORTANT: Free SuiteSparse objects when done
SuiteSparse.matrix_free(a)
SuiteSparse.matrix_free(b)
SuiteSparse.matrix_free(c)
```

The API is identical to the Elixir backend. The `backend:` option selects which implementation runs. The result data structure has the same shape — only the `:data` field contents differ.

## What happens inside mxm

### Step 1: Elixir-side dispatch

```elixir
# In GraphBLAS.Matrix.mxm/4
def mxm(%Matrix{} = a, %Matrix{} = b, semiring \\ :plus_times, opts \\ []) do
  backend = Config.resolve_backend(opts)
  backend.matrix_mxm(a, b, semiring, opts)
end
```

`Config.resolve_backend(opts)` reads the `:backend` key from opts, or falls back to the configured default.

### Step 2: SuiteSparse backend — atom resolution

```elixir
# In GraphBLAS.Backend.SuiteSparse.matrix_mxm/4
def matrix_mxm(%Matrix{data: %{ptr: a_ptr}}, %Matrix{data: %{ptr: b_ptr}}, semiring, _opts) do
  with {:ok, sr} <- resolve_semiring(semiring) do
    semiring_code = semiring_to_code(sr)

    case GraphBLAS.Native.matrix_mxm(a_ptr, b_ptr, semiring_code) do
      ptr when is_integer(ptr) ->
        nrows = GraphBLAS.Native.matrix_nrows(ptr)
        ncols = GraphBLAS.Native.matrix_ncols(ptr)
        {:ok, %Matrix{shape: {nrows, ncols}, type: sr.type, data: %{ptr: ptr}}}

      {:error, reason} ->
        Error.error({:backend_error, __MODULE__, reason})
    end
  end
end
```

The key step: `resolve_semiring(:plus_times)` returns `{:ok, %Semiring{...}}`, then `semiring_to_code/1` maps it to integer code `1`. The NIF receives `1`, not an opaque handle.

### Step 3: NIF boundary — Zig code

```zig
// In the Zig NIF (simplified)
pub fn matrix_mxm(a_ptr: usize, b_ptr: usize, semiring_code: u8) !usize {
    const a = @as(*grb.GrB_Matrix, @ptrFromInt(a_ptr));
    const b = @as(*grb.GrB_Matrix, @ptrFromInt(b_ptr));
    const semiring = semiring_from_code(semiring_code);

    var result: grb.GrB_Matrix = undefined;
    const info = grb.GrB_mxm(
        &result,
        null,           // mask (none)
        null,           // accum (none)
        semiring,
        a.*,
        b.*,
        null,           // descriptor (none)
    );

    if (info != grb.GrB_SUCCESS) {
        return translate_info(info);
    }
    return @intFromPtr(result);
}
```

This runs on a dirty CPU scheduler — it does not block the BEAM.

### Step 4: Back to Elixir

The NIF returns a `usize` integer (the pointer address). The Elixir code wraps it in `%Matrix{data: %{ptr: ptr}}` and returns `{:ok, matrix}`.

No data was copied. The matrix lives in SuiteSparse's memory. Elixir holds only an integer reference to it.

## Pointer lifecycle: creation to destruction

### Creating a matrix

```elixir
{:ok, m} = SuiteSparse.matrix_from_coo(3, 3, entries, :int64, [])
```

What happens:

1. `Backend.SuiteSparse.matrix_from_coo/5` validates dimensions and type
2. Calls `Native.matrix_new(3, 3, 8)` — Zig creates `GrB_Matrix`, returns pointer as `usize`
3. Calls `Native.matrix_build_int64(ptr, rows, cols, vals, length)` — Zig calls `GrB_Matrix_build_INT64`
4. Returns `{:ok, %Matrix{shape: {3, 3}, type: :int64, data: %{ptr: 46128889856}}}`

### Using a matrix

```elixir
{:ok, nvals} = SuiteSparse.matrix_nvals(m)     # Fast, not dirty_cpu
{:ok, coo} = SuiteSparse.matrix_to_coo(m)       # Requires data extraction, dirty_cpu
```

`nvals/1` calls `GrB_Matrix_nvals` — O(1), no dirty scheduler needed.

`to_coo/1` calls `GrB_Matrix_extractTuples_INT64` — copies all data out of SuiteSparse into Elixir lists.

### Destroying a matrix

```elixir
SuiteSparse.matrix_free(m)
```

Explicit. Required. The BEAM garbage collector does NOT free the underlying C memory because the pointer is stored as an integer, not as a managed resource.

**If you forget to free a matrix, it leaks C memory.** This is documented and intentional — the alternative (Zigler resources with GC) was attempted and could not be made to work from `~Z` sigil code.

## Error handling across the boundary

SuiteSparse returns `GrB_Info` error codes. The Zig layer checks these and returns Zig error unions. Zigler converts these to Elixir values.

For functions that return data (`!usize`, `!u64`, `!struct{}`), success returns the value directly and failure returns `{:error, atom}`:

```elixir
# Success path:
case GraphBLAS.Native.matrix_new(3, 3, 8) do
  ptr when is_integer(ptr) -> # success, ptr is the usize pointer
  {:error, reason} -> # failure from SuiteSparse
end

# For void-returning functions:
case GraphBLAS.Native.matrix_free(ptr) do
  :ok -> # success
  {:error, reason} -> # failure
end
```

For functions that can raise (like `grb_init` on double-init), use `try/rescue`:

```elixir
try do
  GraphBLAS.Native.grb_init()
rescue
  _ -> :ok  # Already initialized
end
```

## Type dispatch: why we need type-specific functions

SuiteSparse is a C library. C does not have generics. Instead, SuiteSparse provides type-specific functions:

```c
GrB_Matrix_build_INT64(C, I, J, X, nvals, dup);  // X is int64_t*
GrB_Matrix_build_FP64(C, I, J, X, nvals, dup);   // X is double*
GrB_Matrix_build_BOOL(C, I, J, X, nvals, dup);    // X is bool*
```

In Zigler, we need separate NIF functions for each type:

```elixir
# In GraphBLAS.Native
matrix_build_int64: [:dirty_cpu],
matrix_build_fp64: [:dirty_cpu],
matrix_build_bool: [:dirty_cpu],
```

The Elixir `Backend.SuiteSparse` module dispatches based on the type atom:

```elixir
build_result =
  case type do
    :int64 -> GraphBLAS.Native.matrix_build_int64(ptr, rows, cols, vals, length(entries))
    :fp64 -> GraphBLAS.Native.matrix_build_fp64(ptr, rows, cols, vals, length(entries))
    :bool -> GraphBLAS.Native.matrix_build_bool(ptr, rows, cols, vals, length(entries))
  end
```

## Semiring resolution: atoms to integer codes

SuiteSparse has pre-defined global objects for built-in semirings and monoids. Instead of looking them up by name at runtime, we pass integer codes:

```elixir
# In Backend.SuiteSparse
@semiring_codes %{
  plus_times: 1,
  plus_times_fp64: 2,
  plus_min: 3,
  # ... etc
}

defp semiring_to_code(%Semiring{name: name}), do: Map.fetch!(@semiring_codes, name)
```

In the Zig NIF:

```zig
fn semiring_from_code(code: u8) GrB_Semiring {
    return switch (code) {
        1 => GrB_PLUS_TIMES_SEMIRING_INT64,
        2 => GrB_PLUS_TIMES_SEMIRING_FP64,
        3 => GrB_PLUS_MIN_SEMIRING_INT64,
        // ... etc
    };
}
```

This is a lookup, not a creation. SuiteSparse owns the global semiring objects for the entire process lifetime. We never free them.

**Important naming note**: SuiteSparse uses inconsistent prefixes. The boolean OR monoid is `GxB_LOR_BOOL`, not `GrB_LOR_BOOL`. All symbol names were verified with `nm -g /opt/homebrew/lib/libgraphblas.dylib`.

## Parity testing: the correctness guarantee

The parity tests create identical inputs with both backends, perform the same operation, and compare results:

```elixir
defmodule GraphBLAS.Backend.ParityTest do
  use ExUnit.Case, async: false

  alias GraphBLAS.Backend.Elixir, as: RefBackend
  alias GraphBLAS.Backend.SuiteSparse

  test "int64: both backends produce same mxm result" do
    entries_a = [{0, 1, 1}, {1, 2, 1}]
    entries_b = [{1, 0, 2}, {2, 1, 3}]

    {:ok, ref_a} = RefBackend.matrix_from_coo(2, 3, entries_a, :int64, [])
    {:ok, ref_b} = RefBackend.matrix_from_coo(3, 2, entries_b, :int64, [])
    {:ok, ss_a} = SuiteSparse.matrix_from_coo(2, 3, entries_a, :int64, [])
    {:ok, ss_b} = SuiteSparse.matrix_from_coo(3, 2, entries_b, :int64, [])

    {:ok, ref_c} = RefBackend.matrix_mxm(ref_a, ref_b, :plus_times, [])
    {:ok, ss_c} = SuiteSparse.matrix_mxm(ss_a, ss_b, :plus_times, [])

    {:ok, ref_coo} = RefBackend.matrix_to_coo(ref_c)
    {:ok, ss_coo} = SuiteSparse.matrix_to_coo(ss_c)

    assert sort_coo(ref_coo) == sort_coo(ss_coo)

    # Must free SuiteSparse objects explicitly
    SuiteSparse.matrix_free(ss_a)
    SuiteSparse.matrix_free(ss_b)
    SuiteSparse.matrix_free(ss_c)
  end
end
```

If the two backends disagree, the Elixir backend is right — by definition, because it is the semantic oracle.

## What this walkthrough covered

1. **The boundary**: Elixir → atom resolution → integer code NIF call → `GrB_*` function → usize pointer → wrap in struct
2. **Pointer lifecycle**: Created by NIF, stored as usize in Elixir struct, freed explicitly with `matrix_free`/`vector_free`
3. **Type dispatch**: Separate NIF functions per scalar type because SuiteSparse is type-specific
4. **Semiring resolution**: Atom names map to integer codes, codes map to SuiteSparse global constants in Zig
5. **Error handling**: `GrB_Info` codes → Zig error unions → Elixir exceptions or `{:error, reason}` tuples
6. **Parity testing**: Same inputs, both backends, identical expected results, explicit memory cleanup