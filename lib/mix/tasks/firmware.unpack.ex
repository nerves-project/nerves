# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Firmware.Unpack do
  @shortdoc "Unpack a firmware bundle for inspection"

  @moduledoc """
  Unpack the firmware so that its contents can be inspected locally.

  ## Usage

      mix firmware.unpack [--output output directory] [--fw path to firmware]

  ## Command line options

    * `--fw` - (Optional) The path to the .fw file for unpacking.
      Defaults to `Nerves.Env.firmware_path/1`
    * `--output` - (Optional) The output directory for the unpacked firmware.
      Defaults to the name of the firmware bundle with the extension replaced
      with `.unpacked`.

  ## Examples

  ```
  # Create a firmware bundle. It will be under the _build directory
  mix firmware

  # Unpack the built firmware
  mix firmware.unpack --output firmware_contents

  # Unpack a specified fw file
  mix firmware.unpack --fw hello_nerves.fw

  # Inspect it
  ls hello_nerves.unpacked/
  ```
  """
  use Mix.Task

  alias Nerves.BuildAction.Rootfs
  alias Nerves.MixUtils
  alias Nerves.Preflight

  @switches [output: :string, fw: :string]
  @aliases [o: :output, f: :fw]

  @impl Mix.Task
  def run(args) do
    Preflight.check!()

    {opts, _, _} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    build_plan = Nerves.build_plan()
    fw = opts[:fw] || build_plan.config[:firmware_path]

    cond do
      fw != nil and File.exists?(fw) ->
        :ok

      Mix.target() == :host ->
        Mix.raise("""
        No firmware specified and unspecified target

        Please check that `MIX_TARGET` is set correctly or specify a valid firmware path
        using `--fw`.
        """)

      true ->
        Mix.raise("""
        Firmware not found

        Looked  #{fw}

        Please run `mix firmware` first to create it.
        """)
    end

    output = opts[:output] || "#{Path.rootname(Path.basename(fw))}.unpacked"
    unpack(fw, output, build_plan.config[:rootfs_type])
  end

  defp unpack(fw, output_path, rootfs_type) do
    abs_output_path = Path.expand(output_path)
    rootfs_output_path = Path.join(abs_output_path, "rootfs")
    rootfs_image = Path.join([abs_output_path, "data", "rootfs.img"])

    MixUtils.info("Unpacking to #{output_path}...")

    _ = File.rm_rf!(abs_output_path)
    File.mkdir_p!(abs_output_path)

    {_, 0} = MixUtils.shell("unzip", [fw, "-d", abs_output_path])

    case Rootfs.normalize_rootfs_type(rootfs_type) do
      {:squashfs, _} ->
        {_, 0} =
          MixUtils.shell("unsquashfs", ["-d", rootfs_output_path, "-no-xattrs", rootfs_image])

        :ok

      {:erofs, _} ->
        {_, 0} =
          MixUtils.shell("fsck.erofs", ["--extract=#{rootfs_output_path}", rootfs_image])

        :ok

      other ->
        MixUtils.warning("Skipping RootFS unpack step since it has format #{inspect(other)}")
    end
  end
end
