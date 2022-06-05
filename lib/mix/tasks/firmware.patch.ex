defmodule Mix.Tasks.Firmware.Patch do
  @shortdoc "Build a firmware patch"

  @moduledoc """
  Generate a firmware patch from a source and target firmware and output a new
  firmware file with the patch contents. The source firmware file

  This requires fwup >= 1.6.0

  ## Command line options

    * `--source` - (Optional) The path to the .fw file used as the source.
      Defaults to the last firmware built.
    * `--target` - (Optional) The path to the .fw file used as the target.
      Defaults to generating a new firmware without overwriting the source.
    * `--output` - (Optional) The path to the .fw file used to write the patch
      firmware. Defaults to `Nerves.Env.firmware_path/1`
  """
  use Mix.Task
  import Mix.Nerves.Utils
  alias Mix.Nerves.Preflight
  alias Nerves.Utils.Shell

  @fwup_semver "~> 1.6 or ~> 1.6.0-dev"

  @switches [source: :string, target: :string, output: :string]

  @impl Mix.Task
  def run(args) do
    work_dir = Path.join(Nerves.Env.images_path(), "patch")
    _ = File.rm_rf!(work_dir)
    File.mkdir_p!(work_dir)

    config = Mix.Project.config()
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    Preflight.ensure_fwup_version!("fwup", @fwup_semver)

    source = (opts[:source] || Nerves.Env.firmware_path(config)) |> Path.expand()

    unless File.exists?(source) do
      Mix.raise("""
      Source firmware #{source} does not exist.
      Please pass --source /path/source.fw or run `mix firmware`.
      """)
    end

    source_stats = File.stat!(source)

    target = (opts[:target] || mix_target_firmware(work_dir)) |> Path.expand()
    output = (opts[:output] || Path.join(Nerves.Env.images_path(), "patch.fw")) |> Path.expand()

    Shell.info("""
    Generating patch firmware
    """)

    target_stats = File.stat!(target)

    source_work_dir = Path.join(work_dir, "source")
    target_work_dir = Path.join(work_dir, "target")
    output_work_dir = Path.join(work_dir, "output")

    File.mkdir_p!(source_work_dir)
    File.mkdir_p!(target_work_dir)
    File.mkdir_p!(Path.join(output_work_dir, "data"))

    {_, 0} = shell("unzip", ["-qq", source, "-d", source_work_dir])
    {_, 0} = shell("unzip", ["-qq", target, "-d", target_work_dir])

    source_rootfs = Path.join([source_work_dir, "data", "rootfs.img"])
    target_rootfs = Path.join([target_work_dir, "data", "rootfs.img"])
    out_rootfs = Path.join([output_work_dir, "data", "rootfs.img"])

    {_, 0} = shell("xdelta3", ["-A", "-S", "-f", "-s", source_rootfs, target_rootfs, out_rootfs])

    File.mkdir_p!(Path.dirname(output))
    File.cp!(target, output)

    {_, 0} = shell("zip", ["-qq", output, "data/rootfs.img"], cd: output_work_dir)

    output_stats = File.stat!(output)

    {source_meta, 0} = System.cmd("fwup", ["-m", "-i", source])
    {target_meta, 0} = System.cmd("fwup", ["-m", "-i", target])

    [source_uuid | _] = String.split(source_meta, "meta-uuid=") |> Enum.reverse()
    [target_uuid | _] = String.split(target_meta, "meta-uuid=") |> Enum.reverse()

    source_uuid = String.trim(source_uuid, "\"")
    target_uuid = String.trim(target_uuid, "\"")

    _ = File.rm_rf!(work_dir)

    Shell.success("""

    Finished generating patch firmware

    Source
    #{source}
    uuid: #{source_uuid}
    size: #{source_stats.size} bytes

    Target
    #{target}
    uuid: #{target_uuid}
    size: #{target_stats.size} bytes

    Patch
    #{output}
    size: #{output_stats.size} bytes
    """)
  end

  defp mix_target_firmware(work_dir) do
    Shell.info("Generating new target firmware")
    out_fw = Path.join(work_dir, "target.fw")
    Mix.Tasks.Firmware.run(["--output", out_fw])
    out_fw
  end
end
