# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BinInfoTest do
  use ExUnit.Case, async: true

  alias Nerves.BinInfo

  @fixture_headers %{
    "nerves_toolchain_aarch64_nerves_linux_gnu-linux_x86_64-15.3.0-8DAF9F3" => {:aarch64, 0},
    "nerves_toolchain_aarch64_nerves_linux_musl-linux_x86_64-15.3.0-96B9363" => {:aarch64, 0},
    "nerves_toolchain_armv5_nerves_linux_musleabi-linux_x86_64-15.3.0-CB280CC" =>
      {:arm, 0x500_0200},
    "nerves_toolchain_armv6_nerves_linux_gnueabihf-linux_x86_64-15.3.0-C99C337" =>
      {:arm, 0x500_0400},
    "nerves_toolchain_armv7_nerves_linux_gnueabihf-linux_x86_64-15.3.0-9917D70" =>
      {:arm, 0x500_0400},
    "nerves_toolchain_armv7_nerves_linux_musleabihf-linux_x86_64-15.3.0-AB5A4C8" =>
      {:arm, 0x500_0400},
    "nerves_toolchain_i586_nerves_linux_gnu-linux_x86_64-15.3.0-82A9808" => {:x86, 0},
    "nerves_toolchain_mipsel_nerves_linux_musl-linux_x86_64-15.3.0-4D17880" =>
      {:mips, 0x7000_1007},
    "nerves_toolchain_riscv64_nerves_linux_gnu-linux_x86_64-15.3.0-7D200A9" => {:riscv, 5},
    "nerves_toolchain_riscv64_nerves_linux_musl-linux_x86_64-15.3.0-0513B9F" => {:riscv, 5},
    "nerves_toolchain_x86_64_nerves_linux_gnu-linux_x86_64-15.3.0-C85F8A0" => {:x86_64, 0},
    "nerves_toolchain_x86_64_nerves_linux_musl-linux_x86_64-15.3.0-EA072ED" => {:x86_64, 0}
  }

  test "reads every ELF fixture" do
    fixture_paths = Path.wildcard(Path.join(fixture_directory(), "*"))

    assert fixture_paths
           |> Enum.map(&Path.basename/1)
           |> MapSet.new() == MapSet.new(Map.keys(@fixture_headers))

    Enum.each(@fixture_headers, fn {filename, {machine, flags}} ->
      assert {:ok, %{machine: ^machine, flags: ^flags}} =
               BinInfo.read(Path.join(fixture_directory(), filename))
    end)
  end

  test "reads 32-bit little-endian headers" do
    path = write_fixture(elf_header(1, 1, 40, 0x0500_0200))

    assert {:ok, %{machine: :arm, flags: 0x0500_0200}} = BinInfo.read(path)
  end

  test "reads 64-bit big-endian headers" do
    path = write_fixture(elf_header(2, 2, 183, 0x0102_0304))

    assert {:ok, %{machine: :aarch64, flags: 0x0102_0304}} = BinInfo.read(path)
  end

  test "rejects non-ELF and truncated files" do
    assert :error = BinInfo.read(write_fixture("not an ELF file"))
    assert :error = BinInfo.read(write_fixture(<<0x7F, "ELF", 1, 1>>))
  end

  test "preserves unknown machine values" do
    path = write_fixture(elf_header(1, 1, 0xFFFF, 0))

    assert {:ok, %{machine: 0xFFFF}} = BinInfo.read(path)
  end

  defp elf_header(elf_class, data_encoding, machine, flags) do
    flags_offset = if elf_class == 1, do: 36, else: 48

    <<0x7F, "ELF", elf_class, data_encoding, 1, 0, 0, 0::size(56), 0::size((52 - 16) * 8)>>
    |> put_integer(18, 16, data_encoding, machine)
    |> put_integer(flags_offset, 32, data_encoding, flags)
  end

  defp put_integer(binary, offset, bits, 1, value) do
    put_integer(binary, offset, bits, <<value::little-unsigned-integer-size(bits)>>)
  end

  defp put_integer(binary, offset, bits, 2, value) do
    put_integer(binary, offset, bits, <<value::big-unsigned-integer-size(bits)>>)
  end

  defp put_integer(binary, offset, bits, replacement) do
    size = div(bits, 8)
    <<prefix::binary-size(^offset), _::binary-size(^size), suffix::binary>> = binary
    <<prefix::binary, replacement::binary, suffix::binary>>
  end

  defp write_fixture(contents) do
    path = Path.join(System.tmp_dir!(), "nerves-bin_info-#{System.unique_integer([:positive])}")
    File.write!(path, contents)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp fixture_directory(), do: Path.expand("../fixtures/bin_info", __DIR__)
end
