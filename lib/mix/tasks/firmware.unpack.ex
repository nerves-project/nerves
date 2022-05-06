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
  import Mix.Nerves.Utils
  alias Mix.Nerves.Preflight

  @switches [output: :string, fw: :string]
  @aliases [o: :output, f: :fw]

  @impl Mix.Task
  def run(args) do
    Preflight.check!()
    debug_info("Nerves Firmware Unpack")

    config = Mix.Project.config()

    {opts, _, _} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    fw = opts[:fw] || Nerves.Env.firmware_path(config)
    output = opts[:output] || "#{Path.rootname(Path.basename(fw))}.unpacked"

    _ = check_nerves_system_is_set!()

    _ = check_nerves_toolchain_is_set!()

    unless File.exists?(fw) do
      Mix.raise("""
      Firmware not found.

      Please supply a valid firmware path with `--fw` or run `mix firmware`
      """)
    end

    unpack(fw, output)
  end

  defp unpack(fw, output_path) do
    abs_output_path = Path.expand(output_path)
    rootfs_output_path = Path.join(abs_output_path, "rootfs")
    rootfs_image = Path.join([abs_output_path, "data", "rootfs.img"])

    Mix.shell().info("Unpacking to #{output_path}...")

    _ = File.rm_rf!(abs_output_path)

    File.mkdir_p!(abs_output_path)

    {_, 0} = shell("unzip", [fw, "-d", abs_output_path])

    {_, 0} = shell("unsquashfs", ["-d", rootfs_output_path, "-no-xattrs", rootfs_image])

    :ok
  end
end
