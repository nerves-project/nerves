# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Tar.Reader do
  @moduledoc """
  Read tar archives into a list of `Nerves.Tar.Entry` structs

  Supports POSIX (ustar) tars with PAX extended headers and GNU
  long-name extensions.
  """

  alias Nerves.Tar.Entry

  @record_size 512

  @doc """
  Read a tar file and return a list of entries

  The root `./` entry is filtered out since it duplicates the implicit
  root directory.
  """
  @spec read_tar(Path.t()) :: [Entry.t()]
  def read_tar(tar_path) do
    file = File.open!(tar_path, [:read])

    # Parse the entries, but reject the normal `./` entry that doesn't get
    # used in the output filesystems. `./` also causes sqfstar warnings.
    parse_tar_entries(file, 0, [])
    |> resolve_long_names([])
    |> Enum.reject(fn entry -> entry.path == "./" end)
  end

  defp parse_tar_entries(file, next_offset, acc) do
    case IO.binread(file, @record_size) do
      {:error, reason} ->
        {:error, reason}

      <<0::integer-size(4096)>> ->
        acc

      header_block when byte_size(header_block) == @record_size ->
        {entry, next_offset} =
          read_entry(file, header_block, next_offset + @record_size)

        parse_tar_entries(file, next_offset, [entry | acc])

      _ ->
        acc
    end
  end

  defp round_to_record(value), do: div(value + @record_size - 1, @record_size) * @record_size

  defp read_entry(file, header_block, next_offset) do
    case parse_header(file, header_block, next_offset) do
      %{type: :pax_header, size: pax_size} ->
        rounded_pax_size = round_to_record(pax_size)
        pax_header = IO.binread(file, rounded_pax_size)
        real_header_block = IO.binread(file, @record_size)
        next_offset = next_offset + rounded_pax_size + @record_size

        entry =
          parse_header(file, real_header_block, next_offset)
          |> update_entry_from_pax(pax_header)

        next_offset = next_offset + round_to_record(entry.size)
        {:ok, _} = :file.position(file, next_offset)
        {entry, next_offset}

      %{size: size} = entry ->
        # Skip over the file contents.
        next_offset = next_offset + round_to_record(size)
        {:ok, _} = :file.position(file, next_offset)
        {entry, next_offset}
    end
  end

  defp update_entry_from_pax(entry, pax_header) do
    pax_header
    |> trim_null()
    |> String.split("\n", trim: true)
    |> Enum.reduce(entry, &parse_pax_line/2)
  end

  @pax_line ~r/^\d+\s+([^=]+)=(.*)$/
  defp parse_pax_line(line, entry) do
    case Regex.run(@pax_line, line) do
      [_, key, value] -> pax_update_entry(entry, key, value)
      _ -> entry
    end
  end

  defp pax_update_entry(entry, "linkpath", value), do: %{entry | link: value}
  defp pax_update_entry(entry, "path", value), do: %{entry | path: value}
  defp pax_update_entry(entry, _key, _value), do: entry

  # struct posix_header
  # {                              /* byte offset */
  #   char name[100];               /*   0 */
  #   char mode[8];                 /* 100 */
  #   char uid[8];                  /* 108 */
  #   char gid[8];                  /* 116 */
  #   char size[12];                /* 124 */
  #   char mtime[12];               /* 136 */
  #   char chksum[8];               /* 148 */
  #   char typeflag;                /* 156 */
  #   char linkname[100];           /* 157 */
  #   char magic[6];                /* 257 */
  #   char version[2];              /* 263 */
  #   char uname[32];               /* 265 */
  #   char gname[32];               /* 297 */
  #   char devmajor[8];             /* 329 */
  #   char devminor[8];             /* 337 */
  #   char prefix[155];             /* 345 */
  #                                 /* 500 */
  # };

  # null and space are used interchangeably by different implementations
  @magic ["ustar\0", "ustar "]

  defp parse_header(tar_device, header_block, next_offset) do
    <<filename::100-bytes, mode::8-bytes, uid::8-bytes, gid::8-bytes, size::12-bytes,
      mtime::12-bytes, _chksum::8-bytes, typeflag, linkname::100-bytes, magic::6-bytes,
      _version::2-bytes, _uname::32-bytes, _gname::32-bytes, major_device::8-bytes,
      minor_device::8-bytes, prefix::155-bytes, _::12-bytes>> = header_block

    if magic not in @magic do
      raise "Invalid header magic"
    end

    %Entry{
      path: combine_path(prefix, filename),
      contents: {tar_device, next_offset},
      type: typeflag_to_type(typeflag),
      mode: parse_octal(mode),
      uid: parse_octal(uid),
      gid: parse_octal(gid),
      size: parse_octal(size),
      mtime: parse_octal(mtime),
      link: trim_null(linkname),
      major_device: parse_octal(major_device),
      minor_device: parse_octal(minor_device)
    }
  end

  defp typeflag_to_type(0), do: :regular
  defp typeflag_to_type(?0), do: :regular
  defp typeflag_to_type(?1), do: :hard_link
  defp typeflag_to_type(?2), do: :symlink
  defp typeflag_to_type(?3), do: :character_device
  defp typeflag_to_type(?4), do: :block_device
  defp typeflag_to_type(?5), do: :directory
  defp typeflag_to_type(?K), do: :long_link
  defp typeflag_to_type(?L), do: :long_name
  defp typeflag_to_type(?x), do: :pax_header

  defp parse_octal(str) do
    case str |> trim_null() |> trim_trailing_space() do
      <<>> -> 0
      i -> String.to_integer(i, 8)
    end
  end

  defp trim_null(str), do: String.trim_trailing(str, <<0>>)
  defp trim_trailing_space(str), do: String.trim_trailing(str, " ")

  defp combine_path(prefix, filename) do
    prefix = trim_null(prefix)
    filename = trim_null(filename)

    if prefix == "", do: filename, else: prefix <> "/" <> filename
  end

  # GNU long-name resolution
  #
  # Entries are in reverse order from parsing, so GNU extension entries (K, L)
  # appear *after* the real entry they modify in this list. We consume all
  # consecutive extension entries together so that an entry with both a long
  # name (L) and a long link (K) is handled correctly in one pass.

  defp resolve_long_names(entries, acc)
  defp resolve_long_names([], acc), do: acc

  defp resolve_long_names([entry | tail], acc) do
    {overrides, rest} = collect_gnu_overrides(tail, %{})
    resolve_long_names(rest, [apply_gnu_overrides(entry, overrides) | acc])
  end

  # Collect consecutive GNU extension entries that precede a real entry.
  defp collect_gnu_overrides([%Entry{type: :long_name} = ext | rest], acc) do
    case Entry.read_contents(ext) do
      {:ok, content} -> collect_gnu_overrides(rest, Map.put(acc, :path, trim_null(content)))
      _ -> {acc, [ext | rest]}
    end
  end

  defp collect_gnu_overrides([%Entry{type: :long_link} = ext | rest], acc) do
    case Entry.read_contents(ext) do
      {:ok, content} -> collect_gnu_overrides(rest, Map.put(acc, :link, trim_null(content)))
      _ -> {acc, [ext | rest]}
    end
  end

  defp collect_gnu_overrides(rest, acc), do: {acc, rest}

  defp apply_gnu_overrides(entry, overrides) when map_size(overrides) == 0, do: entry

  defp apply_gnu_overrides(entry, overrides) do
    entry
    |> then(fn e -> if path = overrides[:path], do: Entry.put_path(e, path), else: e end)
    |> then(fn e -> if link = overrides[:link], do: %{e | link: link}, else: e end)
  end
end
