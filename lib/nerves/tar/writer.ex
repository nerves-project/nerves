# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Tar.Writer do
  @moduledoc """
  Write a list of `Nerves.Tar.Entry` structs to a tar archive
  """

  alias Nerves.Tar.Entry

  @doc """
  Write entries to a tar file at the given path
  """
  @spec write_tar(Path.t(), [Entry.t()]) :: :ok
  def write_tar(path, entry_list) when is_binary(path) and is_list(entry_list) do
    File.open!(path, [:write], fn file -> write(file, entry_list) end)
  end

  @doc """
  Write entries to an open IO device.
  """
  @spec write(File.io_device(), [Entry.t()]) :: :ok
  def write(out_device, []) do
    # The end marker is 2 empty 512-byte blocks
    :ok = IO.binwrite(out_device, padding_field(1024))
  end

  def write(out_device, [entry | next]) when is_struct(entry) do
    maybe_write_long_name(out_device, entry)
    maybe_write_long_link(out_device, entry)
    write_header(out_device, entry)
    write_data(out_device, entry)
    write(out_device, next)
  end

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
  defp write_header(out_device, %Entry{} = entry) do
    {filename, prefix} = split_path(entry.path) || {"././@LongLink", ""}
    link = if byte_size(entry.link) > 100, do: "", else: entry.link

    header1 =
      [
        string_field(filename, 100),
        octal_field(entry.mode, 8),
        octal_field(entry.uid, 8),
        octal_field(entry.gid, 8),
        octal_field(entry.size, 12),
        octal_field(0, 12)
      ]
      |> IO.iodata_to_binary()

    header2 =
      [
        type_to_typeflag(entry.type),
        string_field(link, 100),
        "ustar\0",
        "00",
        padding_field(32),
        padding_field(32),
        octal_field(entry.major_device, 8),
        octal_field(entry.minor_device, 8),
        string_field(prefix, 155)
      ]
      |> IO.iodata_to_binary()

    cksum = calculate_checksum(header1, header2)
    :ok = IO.binwrite(out_device, [header1, octal_field(cksum, 8), header2, padding_field(12)])
  end

  # -- Data -------------------------------------------------------------------

  defp write_data(out_device, %Entry{contents: contents, size: size}) when size > 0 do
    write_contents(out_device, contents, size)

    fragment = rem(size, 512)
    padding = if fragment == 0, do: <<>>, else: padding_field(512 - fragment)
    IO.binwrite(out_device, padding)
  end

  defp write_data(_out_device, _entry), do: :ok

  defp maybe_write_long_name(out_device, %Entry{path: path} = entry) do
    case split_path(path) do
      nil ->
        long_name = %{
          entry
          | path: "././@LongLink",
            type: :long_name,
            link: "",
            size: byte_size(path) + 1
        }

        write_header(out_device, long_name)
        write_binary_data(out_device, [path, 0], long_name.size)

      _ ->
        :ok
    end
  end

  defp maybe_write_long_link(out_device, %Entry{link: link} = entry) when byte_size(link) > 100 do
    long_link = %{
      entry
      | path: "././@LongLink",
        type: :long_link,
        link: "",
        size: byte_size(link) + 1
    }

    write_header(out_device, long_link)
    write_binary_data(out_device, [link, 0], long_link.size)
  end

  defp maybe_write_long_link(_out_device, _entry), do: :ok

  defp write_contents(out_device, {path, offset}, size) when is_binary(path) do
    {:ok, :ok} =
      File.open(path, [:read], fn f ->
        {:ok, data} = :file.pread(f, offset, size)
        IO.binwrite(out_device, data)
      end)

    :ok
  end

  defp write_contents(out_device, {in_device, offset}, size) do
    {:ok, data} = :file.pread(in_device, offset, size)
    IO.binwrite(out_device, data)
  end

  defp write_binary_data(out_device, data, size) do
    :ok = IO.binwrite(out_device, data)

    fragment = rem(size, 512)
    padding = if fragment == 0, do: <<>>, else: padding_field(512 - fragment)
    :ok = IO.binwrite(out_device, padding)
  end

  defp calculate_checksum(part1, part2) do
    sum = ?\s * 8

    sum =
      for <<byte <- part1>>, reduce: sum do
        acc -> acc + byte
      end

    for <<byte <- part2>>, reduce: sum do
      acc -> acc + byte
    end
  end

  @doc false
  @spec padding_field(non_neg_integer()) :: binary()
  def padding_field(length), do: <<0::integer-size(length)-unit(8)>>

  @doc false
  @spec string_field(String.t(), non_neg_integer()) :: binary()
  def string_field(str, length) when is_binary(str), do: zero_pad(str, length)

  @doc false
  @spec octal_field(non_neg_integer(), non_neg_integer()) :: iolist()
  def octal_field(number, length) when is_integer(number) do
    number_length = length - 1
    octal = :io_lib.format("~#{number_length}.8.0B", [number])

    # Trying to match what GNU tar does which makes sense when reading the spec
    case length - number_length do
      0 -> octal
      1 -> [octal, 0]
      x -> [octal, 0, :binary.copy(" ", x - 1)]
    end
  end

  @doc false
  @spec zero_pad(String.t(), non_neg_integer()) :: binary()
  def zero_pad(str, length) when is_binary(str) and is_integer(length) do
    str_size = min(byte_size(str), length)
    pad_amount = length - str_size

    <<str::binary-size(str_size), 0::integer-size(pad_amount)-unit(8)>>
  end

  defp split_path(path) when byte_size(path) <= 100, do: {path, ""}

  defp split_path(path) do
    path
    |> String.split("/")
    |> Enum.with_index()
    |> Enum.reduce(nil, fn {_segment, index}, result ->
      {prefix, filename} =
        path
        |> String.split("/", parts: index + 2)
        |> then(fn parts -> {Enum.join(Enum.drop(parts, -1), "/"), List.last(parts)} end)

      if byte_size(prefix) <= 155 and byte_size(filename) <= 100 do
        {filename, prefix}
      else
        result
      end
    end)
  end

  defp type_to_typeflag(:regular), do: ?0
  defp type_to_typeflag(:hard_link), do: ?1
  defp type_to_typeflag(:symlink), do: ?2
  defp type_to_typeflag(:character_device), do: ?3
  defp type_to_typeflag(:block_device), do: ?4
  defp type_to_typeflag(:directory), do: ?5
  defp type_to_typeflag(:long_link), do: ?K
  defp type_to_typeflag(:long_name), do: ?L
end
