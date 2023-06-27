defmodule Mix.Tasks.Firmware do
  @shortdoc "Build a firmware bundle"

  @moduledoc """
  Build a firmware image for the selected target platform.

  This task builds the project, combines the generated OTP release with
  a Nerves system image, and creates a `.fw` file that may be written
  to an SDCard or sent to a device.

  ## Command line options

    * `--verbose` - produce detailed output about release assembly
    * `--output` - (Optional) The path to the .fw file used to write the patch
      firmware. Defaults to `Nerves.Env.firmware_path/1`
  ## Environment variables

    * `NERVES_SYSTEM`    - may be set to a local directory to specify the Nerves
      system image that is used

    * `NERVES_TOOLCHAIN` - may be set to a local directory to specify the
      Nerves toolchain (C/C++ crosscompiler) that is used
  """
  use Mix.Task
  import Mix.Nerves.Utils
  alias Mix.Nerves.Preflight

  @default_mksquashfs_flags ["-no-xattrs", "-quiet"]

  @switches [verbose: :boolean, output: :string]

  @impl Mix.Task
  def run(args) do
    Preflight.check!()
    debug_info("Nerves Firmware Assembler")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    system_path = check_nerves_system_is_set!()

    _ = check_nerves_toolchain_is_set!()

    # By this point, paths have already been loaded.
    # We just want to ensure any custom systems are compiled
    # via the precompile checks
    Mix.Task.run("nerves.precompile", ["--no-loadpaths"])
    Mix.Task.run("compile", [])

    Mix.Nerves.IO.shell_info("Building OTP Release...")

    build_release()

    config = Mix.Project.config()
    fw_out = opts[:output] || Nerves.Env.firmware_path(config)
    build_firmware(config, system_path, fw_out)
  end

  @doc false
  @spec result({Collectable.t(), exit_status :: non_neg_integer()}) :: :ok
  def result({_, 0}) do
    Mix.shell().info("""
    Firmware built successfully! 🎉

    Now you may install it to a MicroSD card using `mix burn` or upload it
    to a device with `mix upload` or `mix firmware.gen.script`+`./upload.sh`.
    """)
  end

  def result({%IO.Stream{}, err}) do
    # Any output was already sent through the stream,
    # so just halt at this point
    System.halt(err)
  end

  def result({result, _}) do
    Mix.raise("""
    Nerves encountered an error. #{inspect(result)}
    """)
  end

  defp build_release() do
    Mix.Task.run("release", [])
  end

  defp build_firmware(config, system_path, fw_out) do
    otp_app = config[:app]
    compiler_check()
    firmware_config = Application.get_env(:nerves, :firmware)

    mksquashfs_flags = firmware_config[:mksquashfs_flags] || @default_mksquashfs_flags
    set_mksquashfs_flags(mksquashfs_flags)

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

    build_rootfs_overlay = Path.join([Mix.Project.build_path(), "nerves", "rootfs_overlay"])
    File.mkdir_p!(build_rootfs_overlay)

    write_erlinit_config(build_rootfs_overlay)

    project_rootfs_overlay =
      case firmware_config[:rootfs_overlay] || firmware_config[:rootfs_additions] do
        nil ->
          []

        overlays when is_list(overlays) ->
          overlays

        overlay ->
          [Path.expand(overlay)]
      end

    prevent_overlay_overwrites!(project_rootfs_overlay)

    rootfs_overlays =
      [build_rootfs_overlay | project_rootfs_overlay]
      |> Enum.map(&["-a", &1])
      |> List.flatten()

    fwup_conf =
      case firmware_config[:fwup_conf] do
        nil -> []
        fwup_conf -> ["-c", Path.join(File.cwd!(), fwup_conf)]
      end

    fw = ["-f", fw_out]
    release_path = Path.join(Mix.Project.build_path(), "rel/#{otp_app}")
    output = [release_path]
    args = args ++ fwup_conf ++ rootfs_overlays ++ fw ++ rootfs_priorities ++ output
    env = [{"MIX_BUILD_PATH", Mix.Project.build_path()} | standard_fwup_variables(config)]

    set_provisioning(firmware_config[:provisioning])

    config
    |> Nerves.Env.images_path()
    |> File.mkdir_p!()

    shell(cmd, args, env: env)
    |> result()
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

  defp compiler_check() do
    {:ok, otpc} = erlang_compiler_version()
    {:ok, elixirc} = elixir_compiler_version()

    if otpc.major != elixirc.major do
      Mix.raise("""
      Elixir was compiled by a different version of the Erlang/OTP compiler
      than is being used now. This may not work.

      Erlang compiler used for Elixir: #{elixirc.major}.#{elixirc.minor}.#{elixirc.patch}
      Current Erlang compiler:         #{otpc.major}.#{otpc.minor}.#{otpc.patch}

      Please use a version of Elixir that was compiled using the same major
      version.

      For example:

      If your target is running OTP 25, you should use a version of Elixir
      that was compiled using OTP 25.

      If you're using asdf to manage Elixir versions, run:

      asdf install elixir #{System.version()}-otp-#{System.otp_release()}
      asdf global elixir #{System.version()}-otp-#{System.otp_release()}
      """)
    end
  end

  defp erlang_compiler_version() do
    Application.spec(:compiler, :vsn)
    |> to_string()
    |> parse_otp_version()
  end

  defp elixir_compiler_version() do
    {:file, path} = :code.is_loaded(Kernel)
    {:ok, {_, [compile_info: compile_info]}} = :beam_lib.chunks(path, [:compile_info])
    {:ok, vsn} = Keyword.fetch(compile_info, :version)

    vsn
    |> to_string()
    |> parse_otp_version()
  end

  defp write_erlinit_config(build_overlay) do
    with user_opts <- Application.get_env(:nerves, :erlinit, []),
         {:ok, system_config_file} <- Nerves.Erlinit.system_config_file(Nerves.Env.system()),
         {:ok, system_config_file} <- File.read(system_config_file),
         system_opts <- Nerves.Erlinit.decode_config(system_config_file),
         erlinit_opts <- Nerves.Erlinit.merge_opts(system_opts, user_opts),
         erlinit_config <- Nerves.Erlinit.encode_config(erlinit_opts) do
      erlinit_config_file = Path.join(build_overlay, "etc/erlinit.config")

      Path.dirname(erlinit_config_file)
      |> File.mkdir_p!()

      header = erlinit_config_header(user_opts)

      File.write!(erlinit_config_file, header <> erlinit_config)
    else
      {:error, :no_config} ->
        Nerves.Utils.Shell.warn("There was no system erlinit.config found")
        :ok

      e ->
        Nerves.Utils.Shell.warn("Error constructing  erlinit.config: #{inspect(e)}")
        :ok
    end
  end

  @doc false
  @spec erlinit_config_header(Keyword.t()) :: String.t()
  def erlinit_config_header(opts) do
    """
    # Generated from rootfs_overlay/etc/erlinit.config
    """ <>
      if opts != [] do
        """
        # with overrides from the application config
        """
      else
        """
        """
      end
  end

  defp set_mksquashfs_flags(flags) when is_list(flags) do
    System.put_env("NERVES_MKSQUASHFS_FLAGS", Enum.join(flags, " "))
  end

  @restricted_fs ["data", "root", "tmp", "dev", "sys", "proc"]
  defp prevent_overlay_overwrites!(overlay_dirs) do
    shadow_mounts =
      for dir <- overlay_dirs,
          p <- Path.wildcard([dir, "/*"]),
          fs_dir = Path.relative_to(p, dir),
          fs_dir in @restricted_fs,
          Path.wildcard([p, "/*"]) != [],
          do: Path.relative_to_cwd(p)

    if length(shadow_mounts) > 0 do
      Mix.raise("""
      The firmware contains overlay files which reference directories that are
      mounted as file systems on the device. The filesystem mount will completely
      overwrite the overlay and these files will be lost.

      Remove the following overlay directories and build the firmware again:

      #{for dir <- shadow_mounts, do: "  * #{dir}\n"}
      #{IO.ANSI.reset()}https://hexdocs.pm/nerves/advanced-configuration.html#root-filesystem-overlays
      """)
    end
  end
end
