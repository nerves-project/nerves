# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Tar.RoundTripTest do
  use ExUnit.Case, async: true

  alias Nerves.Tar.Entry
  alias Nerves.Tar.Reader
  alias Nerves.Tar.Writer

  @moduletag :tmp_dir

  test "write and read back regular files", %{tmp_dir: tmp_dir} do
    content_file = Path.join(tmp_dir, "content.bin")
    File.write!(content_file, "file contents here")

    entries = [
      Entry.directory("/mydir", mode: 0o755),
      Entry.regular("/mydir/file.txt",
        contents: {content_file, 0},
        mode: 0o644,
        size: 18
      ),
      Entry.directory("/srv", mode: 0o755),
      Entry.directory("/srv/erlang", mode: 0o755),
      Entry.directory("/srv/erlang/lib", mode: 0o755),
      Entry.directory("/srv/erlang/lib/vintage_net_wifi-0.12.11", mode: 0o755),
      Entry.directory("/srv/erlang/lib/vintage_net_wifi-0.12.11/ebin", mode: 0o755),
      Entry.regular(
        "/srv/erlang/lib/vintage_net_wifi-0.12.11/ebin/Elixir.VintageNetWiFi.MeshPeer.FormationInformation.beam",
        contents: {content_file, 0},
        mode: 0o644,
        size: 18
      )
    ]

    tar_path = Path.join(tmp_dir, "test.tar")
    Writer.write_tar(tar_path, entries)

    read_back = Reader.read_tar(tar_path)
    assert length(read_back) == 8

    directories = Enum.filter(read_back, &(&1.type == :directory))
    assert length(directories) == 6

    [first_dir | _beam_dirs] = directories
    assert first_dir.path == "./mydir/"
    assert first_dir.mode == 0o755

    regular_files = Enum.filter(read_back, &(&1.type == :regular))
    assert length(regular_files) == 2

    [file_text, long_file] = regular_files
    assert file_text.path == "./mydir/file.txt"
    assert file_text.mode == 0o644
    assert file_text.size == 18

    {:ok, data} = Entry.read_contents(file_text)
    assert data == "file contents here"

    assert long_file.path ==
             "./srv/erlang/lib/vintage_net_wifi-0.12.11/ebin/Elixir.VintageNetWiFi.MeshPeer.FormationInformation.beam"

    assert long_file.mode == 0o644
    assert long_file.size == 18
  end

  test "write and read back symlinks", %{tmp_dir: tmp_dir} do
    entries = [
      Entry.directory("/dev", mode: 0o755),
      Entry.symlink("/dev/ttyABC", mode: 0o777, link: "ttyS0"),
      Entry.symlink(
        "/etc/ssl/certs/Autoridad_de_Certificacion_Firmaprofesional_CIF_A62634068.pem",
        mode: 0o777,
        link:
          "../../../usr/share/ca-certificates/mozilla/Autoridad_de_Certificacion_Firmaprofesional_CIF_A62634068.crt"
      )
    ]

    tar_path = Path.join(tmp_dir, "symlink.tar")
    Writer.write_tar(tar_path, entries)

    read_back = Reader.read_tar(tar_path)
    [short_link, long_link] = Enum.filter(read_back, &(&1.type == :symlink))
    assert short_link.path == "./dev/ttyABC"
    assert short_link.link == "ttyS0"

    assert long_link.path ==
             "./etc/ssl/certs/Autoridad_de_Certificacion_Firmaprofesional_CIF_A62634068.pem"

    assert long_link.link ==
             "../../../usr/share/ca-certificates/mozilla/Autoridad_de_Certificacion_Firmaprofesional_CIF_A62634068.crt"
  end

  test "write and read back a regular file with a GNU long name", %{tmp_dir: tmp_dir} do
    content_file = Path.join(tmp_dir, "content.bin")
    File.write!(content_file, "file contents here")

    path =
      "/srv/erlang/lib/blue_heron-0.5.4/ebin/Elixir.BlueHeron.HCI.Serializable.BlueHeron.HCI.Command.LinkPolicy.WriteDefaultLinkPolicySettings.beam"

    tar_path = Path.join(tmp_dir, "long_name.tar")

    Writer.write_tar(tar_path, [
      Entry.regular(path, contents: {content_file, 0}, mode: 0o644, size: 18)
    ])

    [entry] = Reader.read_tar(tar_path)
    assert entry.path == "." <> path
    assert entry.mode == 0o644
    assert entry.size == 18
  end

  test "write and read back device nodes", %{tmp_dir: tmp_dir} do
    entries = [
      Entry.directory("/dev", mode: 0o755),
      Entry.block_device("/dev/sda", mode: 0o660, major_device: 8, minor_device: 0),
      Entry.character_device("/dev/ttyS0", mode: 0o660, major_device: 4, minor_device: 64)
    ]

    tar_path = Path.join(tmp_dir, "devices.tar")
    Writer.write_tar(tar_path, entries)

    read_back = Reader.read_tar(tar_path)

    block = Enum.find(read_back, &(&1.type == :block_device))
    assert block.path == "./dev/sda"
    assert block.major_device == 8
    assert block.minor_device == 0

    char = Enum.find(read_back, &(&1.type == :character_device))
    assert char.path == "./dev/ttyS0"
    assert char.major_device == 4
    assert char.minor_device == 64
  end
end
