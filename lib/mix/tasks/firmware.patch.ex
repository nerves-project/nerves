defmodule Mix.Tasks.Firmware.Patch do
  @shortdoc "Build a firmware patch"

  @moduledoc """
  Generate a firmware patch from a source and target firmware and output a new
  firmware file with the patch contents. The source firmware file

  This requires fwup >= 1.10.0

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

  @fwup_semver ">= 1.10.0"

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

    _ = create(source, target, output, work_dir)

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

  defp create(source_path, target_path, output_path, work_dir) do
    source_work_dir = Path.join(work_dir, "source")
    target_work_dir = Path.join(work_dir, "target")
    output_work_dir = Path.join(work_dir, "output")

    _ = File.mkdir_p(source_work_dir)
    _ = File.mkdir_p(target_work_dir)
    _ = File.mkdir_p(output_work_dir)

    {_, 0} = shell("unzip", ["-qq", source_path, "-d", source_work_dir])
    {_, 0} = shell("unzip", ["-qq", target_path, "-d", target_work_dir])

    for path <- Path.wildcard(target_work_dir <> "/**") do
      path = Regex.replace(~r/^#{target_work_dir}\//, path, "")

      unless File.dir?(Path.join(target_work_dir, path)) do
        :ok = handle_content(path, source_work_dir, target_work_dir, output_work_dir)
      end
    end

    # firmware archive files order matters:
    # 1. meta.conf.ed25519 (optional)
    # 2. meta.conf
    # 3. other...
    [
      "meta.conf.*",
      "meta.conf",
      "data"
    ]
    |> Enum.each(&add_to_zip(&1, output_work_dir, output_path))

    output_path
  end

  defp handle_content("meta." <> _ = path, _source_dir, target_dir, out_dir) do
    do_copy(Path.join(target_dir, path), Path.join(out_dir, path))
  end

  defp handle_content(path, source_dir, target_dir, out_dir) do
    do_delta(Path.join(source_dir, path), Path.join(target_dir, path), Path.join(out_dir, path))
  end

  defp do_copy(source, target) do
    target |> Path.dirname() |> File.mkdir_p!()
    File.cp(source, target)
  end

  defp do_delta(source, target, out) do
    out |> Path.dirname() |> File.mkdir_p!()

    case shell("xdelta3", ["-A", "-S", "-f", "-s", source, target, out]) do
      {_, 0} -> :ok
      {_, code} -> {:error, code}
    end
  end

  defp add_to_zip(glob, workdir, output) do
    workdir
    |> Path.join(glob)
    |> Path.wildcard()
    |> case do
      [] ->
        :ok

      paths ->
        {_, 0} =
          System.cmd(
            "zip",
            ["-r", "-qq", output | Enum.map(paths, &Path.relative_to(&1, workdir))],
            cd: workdir
          )

        :ok
    end
  end
end
