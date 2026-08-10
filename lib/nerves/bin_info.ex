# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BinInfo do
  @moduledoc """
  Parse executable binaries and return architecture and other info

  This is intentionally minimal for the Nerves use cases. It only
  looks at headers so that it can extract compatibility information
  as fast as possible.
  """

  # This is a minimal ELF header parser for checking that executables
  # have a chance of running on the target processor.
  #
  # See https://refspecs.linuxfoundation.org/elf/gabi4+/ch4.eheader.html
  # and https://en.wikipedia.org/wiki/Executable_and_Linkable_Format
  @type machine() ::
          :aarch64 | :arm | :mips | :riscv | :x86 | :x86_64 | :unknown | non_neg_integer()
  @type type() :: :elf | :macho | :script
  @type info() :: %{
          type: type(),
          machine: machine(),
          flags: non_neg_integer(),
          endian: :big | :little | :unknown,
          bits: 32 | 64
        }

  # Subset of architectures for supported Nerves toolchains
  @machines %{
    3 => :x86,
    8 => :mips,
    40 => :arm,
    62 => :x86_64,
    183 => :aarch64,
    243 => :riscv
  }

  @macos_machines %{
    0x7 => :x86,
    0xC => :arm,
    0x1000007 => :x86_64,
    0x100000C => :arm
  }

  @doc """
  Read compilation information from the specified file
  """
  @spec read(Path.t()) :: {:ok, info()} | :error
  def read(path) do
    case File.open(path, [:read, :binary], &IO.binread(&1, 0x40)) do
      {:ok, header} when is_binary(header) -> parse_header(header)
      _ -> :error
    end
  end

  @doc """
  Return the file type
  """
  @spec file_type(Path.t()) :: type() | :error
  def file_type(path) do
    case read(path) do
      {:ok, %{type: type}} -> type
      _ -> :error
    end
  end

  defp parse_header(<<0x7F, "ELF", elf_class, data_encoding, _::binary-size(10), rest::binary>>) do
    fields(elf_class, data_encoding, rest)
  end

  # Detect macOS binaries since this is a common error case
  defp parse_header(<<0xFEEDFACE::little-32, machine::little-32, _::binary>>),
    do:
      {:ok, %{type: :macho, machine: macos_machine(machine), flags: 0, bits: 32, endian: :little}}

  defp parse_header(<<0xFEEDFACF::little-32, machine::little-32, _::binary>>),
    do:
      {:ok, %{type: :macho, machine: macos_machine(machine), flags: 0, bits: 64, endian: :little}}

  defp parse_header(<<0xFEEDFACE::big-32, machine::big-32, _::binary>>),
    do: {:ok, %{type: :macho, machine: macos_machine(machine), flags: 0, bits: 32, endian: :big}}

  defp parse_header(<<0xFEEDFACF::big-32, machine::big-32, _::binary>>),
    do: {:ok, %{type: :macho, machine: macos_machine(machine), flags: 0, bits: 64, endian: :big}}

  defp parse_header(<<"#!/, _::binary">>),
    do: {:ok, %{type: :script, machine: :unknown, flags: 0, bits: :unknown, endian: :unknown}}

  defp parse_header(_header), do: :error

  # ELF: 32-bit LE
  defp fields(1, 1, <<_::16, machine::little-16, _::128, flags::little-32, _::binary>>),
    do: {:ok, %{type: :elf, machine: machine(machine), bits: 32, flags: flags, endian: :little}}

  # ELF: 32-bit BE
  defp fields(1, 2, <<_::16, machine::big-16, _::128, flags::big-32, _::binary>>),
    do: {:ok, %{type: :elf, machine: machine(machine), bits: 32, flags: flags, endian: :big}}

  # ELF: 64-bit LE
  defp fields(2, 1, <<_::16, machine::little-16, _::224, flags::little-32, _::binary>>),
    do: {:ok, %{type: :elf, machine: machine(machine), bits: 64, flags: flags, endian: :little}}

  # ELF: 64-bit BE
  defp fields(2, 2, <<_::16, machine::big-16, _::224, flags::big-32, _::binary>>),
    do: {:ok, %{type: :elf, machine: machine(machine), bits: 64, flags: flags, endian: :big}}

  defp fields(_, _, _), do: :error

  defp machine(value), do: Map.get(@machines, value, value)
  defp macos_machine(value), do: Map.get(@macos_machines, value, value)
end
