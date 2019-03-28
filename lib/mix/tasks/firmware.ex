defmodule Mix.Tasks.Firmware do
  use Mix.Task
  import Mix.Nerves.Utils

  @shortdoc "Build a firmware bundle"

  @moduledoc """
  Build a firmware image for the selected target platform.

  This task builds the project, combines the generated OTP release with
  a Nerves system image, and creates a `.fw` file that may be written
  to an SDCard or sent to a device.

  ## Command line options

    * `--verbose` - produce detailed output about release assembly

  ## Environment variables

    * `NERVES_SYSTEM`    - may be set to a local directory to specify the Nerves
      system image that is used

    * `NERVES_TOOLCHAIN` - may be set to a local directory to specify the
      Nerves toolchain (C/C++ crosscompiler) that is used
  """

  @switches [verbose: :boolean]

  @impl true
  def run(args) do
    preflight()
    debug_info("Nerves Firmware Assembler")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    system_path = check_nerves_system_is_set!()

    check_nerves_toolchain_is_set!()

    rel_config =
      File.cwd!()
      |> Path.join("rel/config.exs")

    unless File.exists?(rel_config) do
      Mix.raise("""
        You are missing a release config file. Run  nerves.release.init task first
      """)
    end

    Mix.Task.run("compile", [])

    Mix.Nerves.IO.shell_info("Building OTP Release...")
    clean_release(opts)
    build_release(opts)
    build_firmware(system_path)
  end

  @doc false
  def result({_, 0}), do: nil

  def result({result, _}),
    do:
      Mix.raise("""
      Nerves encountered an error. #{inspect(result)}
      """)

  defp clean_release(opts) do
    verbosity = if opts[:verbose], do: "--verbose", else: "--silent"

    try do
      Mix.Task.run("release.clean", [verbosity, "--implode", "--no-confirm"])
    catch
      :exit, _ -> :noop
    end
  end

  defp build_release(opts) do
    verbosity = if opts[:verbose], do: "--verbose", else: "--quiet"
    Mix.Task.run("release", [verbosity, "--no-tar"])
  end

  defp build_firmware(system_path) do
    config = Mix.Project.config()
    otp_app = config[:app]

    images_path =
      (config[:images_path] || Path.join([Mix.Project.build_path(), "nerves", "images"]))
      |> Path.expand()

    unless File.exists?(images_path) do
      File.mkdir_p(images_path)
    end

    firmware_config = Application.get_env(:nerves, :firmware)

    rootfs_priorities =
      Nerves.Env.package(:nerves_system_br)
      |> rootfs_priorities()

    rel2fw_path = Path.join(system_path, "scripts/rel2fw.sh")
    cmd = "bash"
    args = [rel2fw_path]

    if firmware_config[:rootfs_additions] do
      Mix.shell().error(
        "The :rootfs_additions configuration option has been deprecated. Please use :rootfs_overlay instead."
      )
    end

    rootfs_overlay =
      case firmware_config[:rootfs_overlay] || firmware_config[:rootfs_additions] do
        nil ->
          []

        overlays when is_list(overlays) ->
          Enum.map(overlays, fn overlay -> ["-a", Path.join(File.cwd!(), overlay)] end)
          |> List.flatten()

        overlay ->
          ["-a", Path.join(File.cwd!(), overlay)]
      end

    fwup_conf =
      case firmware_config[:fwup_conf] do
        nil -> []
        fwup_conf -> ["-c", Path.join(File.cwd!(), fwup_conf)]
      end

    fw = ["-f", "#{images_path}/#{otp_app}.fw"]
    release_path = Path.join(Mix.Project.build_path(), "rel/#{otp_app}")
    output = [release_path]
    args = args ++ fwup_conf ++ rootfs_overlay ++ fw ++ rootfs_priorities ++ output
    env = standard_fwup_variables(config)

    set_provisioning(firmware_config[:provisioning])

    shell(cmd, args, env: env)
    |> result
  end

  defp standard_fwup_variables(config) do
    # Assuming the fwup.conf file respects these variable like the official
    # systems do, this will set the .fw metadata to what's in the mix.exs.
    [
      {"NERVES_FW_VERSION", config[:version]},
      {"NERVES_FW_PRODUCT", config[:name] || to_string(config[:app])},
      {"NERVES_FW_DESCRIPTION", config[:description]},
      {"NERVES_FW_AUTHOR", config[:author]}
    ]
  end

  # Need to check min version for nerves_system_br to check if passing the
  # rootfs priorities option is supported. This was added in the 1.7.1 release
  # https://github.com/nerves-project/nerves_system_br/releases/tag/v1.7.1
  defp rootfs_priorities(%Nerves.Package{app: :nerves_system_br, version: vsn}) do
    case Version.compare(vsn, "1.7.1") do
      r when r in [:gt, :eq] ->
        rootfs_priorities_file =
          Path.join([Mix.Project.build_path(), "nerves", "rootfs.priorities"])

        if File.exists?(rootfs_priorities_file) do
          ["-p", rootfs_priorities_file]
        else
          []
        end

      _ ->
        []
    end
  end

  defp rootfs_priorities(_), do: []
end
