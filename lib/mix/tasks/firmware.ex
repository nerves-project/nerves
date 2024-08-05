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

  import Mix.Nerves.Utils,
    only: [
      check_nerves_system_is_set!: 0,
      check_nerves_toolchain_is_set!: 0,
      parse_otp_version: 1,
      set_provisioning: 1,
      shell: 3
    ]

  import Mix.Nerves.IO, only: [debug_info: 1]
  alias Mix.Nerves.Preflight

  @switches [verbose: :boolean, output: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    if opts[:verbose], do: System.put_env("NERVES_DEBUG", "1")
    debug_info("firmware build start")

    Preflight.check!()

    config = build_config!(opts)
    compiler_check!()

    # By this point, paths have already been loaded.
    # We just want to ensure any custom systems are compiled
    # via the precompile checks
    Mix.Task.run("nerves.precompile", ["--no-loadpaths"])
    Mix.Task.run("compile", [])

    {time, _result} = :timer.tc(fn -> Mix.Task.run("release", []) end)
    debug_info("OTP release : #{time / 1.0e6}s")

    write_erlinit_config!(config)
    prevent_overlay_overwrites!(config)

    build_from_tar? =
      config.fs_type == :erofs or Path.extname(config.system_rootfs_path) == ".tar"

    # build_result =
    {time, build_result} =
      :timer.tc(fn ->
        if build_from_tar?,
          do: build_firmware(config),
          else: build_firmware_legacy(config)
      end)

    _ = File.rm_rf!(config.tmp_dir)

    debug_info("mkfs : #{time / 1.0e6}s")
    result(build_result, config)
    debug_info("firmware build end")
  end

  defp build_config!(opts) do
    firmware_config = Application.get_env(:nerves, :firmware, [])
    mix_config = Mix.Project.config()

    # Enforce required pieces
    system_path = check_nerves_system_is_set!()
    toolchain_path = check_nerves_toolchain_is_set!()
    set_provisioning(firmware_config[:provisioning])

    # Build configuration
    build_rootfs_overlay = Path.join([Mix.Project.build_path(), "nerves", "rootfs_overlay"])
    File.mkdir_p!(build_rootfs_overlay)

    tmp_dir = Path.join(Mix.Project.build_path(), "_nerves-tmp")
    _ = File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    project_rootfs_overlays =
      case firmware_config[:rootfs_overlay] do
        nil ->
          []

        overlays when is_list(overlays) ->
          overlays

        overlay ->
          [Path.expand(overlay)]
      end

    system_images = Path.join(system_path, "images")

    fwup_conf =
      if conf_path = firmware_config[:fwup_conf] do
        Path.join(File.cwd!(), conf_path)
      else
        Path.join(system_images, "fwup.conf")
      end

    system_rootfs =
      with path <- Path.join(system_images, "rootfs.tar"),
           true <- File.exists?(path) do
        path
      else
        _ -> Path.join(system_images, "rootfs.squashfs")
      end

    output = opts[:output] || Nerves.Env.firmware_path(mix_config)
    # Make sure the fw dir path exists for fwup to write to
    File.mkdir_p!(Path.dirname(output))

    %{
      build_rootfs_overlay: build_rootfs_overlay,
      env: build_env(mix_config),
      erofs_options: firmware_config[:erofs_options] || [],
      fs_type: firmware_config[:fs_type] || :squashfs,
      fwup_conf: fwup_conf,
      mksquashfs_flags: firmware_config[:mksquashfs_flags] || [],
      output: output,
      project_rootfs_overlays: project_rootfs_overlays,
      release_path: Path.join(Mix.Project.build_path(), "rel/#{mix_config[:app]}"),
      system_path: system_path,
      system_rootfs_path: system_rootfs,
      tmp_dir: tmp_dir,
      toolchain_path: toolchain_path,
      verbose: opts[:verbose]
    }
  end

  defp build_env(mix_config) do
    # Assuming the fwup.conf file respects these variable like the official
    # systems do, this will set the .fw metadata to what's in the mix.exs.
    [
      {"MIX_BUILD_PATH", Mix.Project.build_path()},
      {"NERVES_FW_VERSION", mix_config[:version]},
      {"NERVES_FW_PRODUCT", mix_config[:name] || to_string(mix_config[:app])},
      {"NERVES_FW_DESCRIPTION", mix_config[:description]},
      {"NERVES_FW_AUTHOR", mix_config[:author]}
    ]
  end

  defp result({_, 0}, config) do
    args = ["-m", "--metadata-key", "meta-uuid", "-i", config.output]
    {uuid, _} = shell("fwup", args, stream: "")
    formatted = IO.ANSI.format([:green, String.trim(uuid)])

    Mix.shell().info("""
    Firmware built successfully! 🎉 [#{formatted}]

    Now you may install it to a MicroSD card using `mix burn` or upload it
    to a device with `mix upload` or `mix firmware.gen.script`+`./upload.sh`.
    """)
  end

  defp result(:error, _config), do: System.halt(1)

  defp result({%IO.Stream{}, err}, _config) do
    # Any output was already sent through the stream,
    # so just halt at this point
    System.halt(err)
  end

  defp result({result, _}, _config) do
    Mix.raise("""
    Nerves encountered an error. #{inspect(result)}
    """)
  end

  defp build_firmware(config) do
    # Order matters. First == highest priority
    entries =
      [
        # TODO: Scrub unsupported files?
        Enum.map(config.project_rootfs_overlays, &TarMerger.scan_directory/1),
        TarMerger.scan_directory(config.build_rootfs_overlay),
        TarMerger.scan_directory(config.release_path, "/srv/erlang"),
        TarMerger.read_tar(config.system_rootfs_path)
      ]
      |> TarMerger.merge()
      |> TarMerger.sort()

    rootfs = Path.join(config.tmp_dir, "rootfs.#{config.fs_type}")

    with :ok <- mkfs(rootfs, entries, config) do
      args = ["-c", "-f", config.fwup_conf, "-o", config.output]
      env = [{"ROOTFS", rootfs} | config.env]
      shell("fwup", args, env: env)
    end
  end

  defp mkfs(rootfs, entries, %{fs_type: :erofs} = config) do
    mkfs_tmp = Path.join(config.tmp_dir, "mkfs.erofs-tmp")
    File.mkdir_p!(mkfs_tmp)
    TarMerger.mkfs_erofs(rootfs, entries, erofs_options: config.erofs_options, tmp_dir: mkfs_tmp)
  end

  defp mkfs(rootfs, entries, config) do
    mkfs_tmp = Path.join(config.tmp_dir, "mkfs.squashfs-tmp")
    File.mkdir_p!(mkfs_tmp)

    TarMerger.mkfs_squashfs(rootfs, entries,
      mksquashfs_options: config.mksquashfs_flags,
      tmp_dir: mkfs_tmp
    )
  end

  defp build_firmware_legacy(config) do
    # Need to check min version for nerves_system_br to check if passing the
    # rootfs priorities option is supported. This was added in the 1.7.1 release
    # https://github.com/nerves-project/nerves_system_br/releases/tag/v1.7.1
    rootfs_priorities_arg =
      with %Nerves.Package{app: :nerves_system_br, version: vsn} <-
             Nerves.Env.package(:nerves_system_br),
           r when r in [:gt, :eq] <- Version.compare(vsn, "1.7.1"),
           rootfs_priorities_file =
             Path.join([Mix.Project.build_path(), "nerves", "rootfs.priorities"]),
           true <- File.exists?(rootfs_priorities_file) do
        ["-p", rootfs_priorities_file]
      else
        _ -> []
      end

    rootfs_overlay_args =
      [config.build_rootfs_overlay | config.project_rootfs_overlays]
      |> Enum.map(&["-a", &1])

    args =
      [
        Path.join(config.system_path, "scripts/rel2fw.sh"),
        "-c",
        config.fwup_conf,
        "-f",
        config.output,
        rootfs_overlay_args,
        rootfs_priorities_arg,
        config.release_path
      ]
      |> List.flatten()

    flags =
      if Enum.empty?(config.mksquashfs_flags),
        do: ["-no-xattrs", "-quiet"],
        else: config.mksquashfs_flags

    env = [{"NERVES_MKSQUASHFS_FLAGS", Enum.join(flags, " ")} | config.env]

    shell("bash", args, env: env)
  end

  defp compiler_check!() do
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

  defp write_erlinit_config!(config) do
    with user_opts <- Application.get_env(:nerves, :erlinit, []),
         {:ok, system_config_file} <- Nerves.Erlinit.system_config_file(Nerves.Env.system()),
         {:ok, system_config_file} <- File.read(system_config_file),
         system_opts <- Nerves.Erlinit.decode_config(system_config_file),
         erlinit_opts <- Nerves.Erlinit.merge_opts(system_opts, user_opts),
         erlinit_config <- Nerves.Erlinit.encode_config(erlinit_opts) do
      erlinit_config_file = Path.join(config.build_rootfs_overlay, "etc/erlinit.config")

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

  @restricted_fs ["data", "root", "tmp", "dev", "sys", "proc"]
  defp prevent_overlay_overwrites!(config) do
    shadow_mounts =
      for dir <- config.project_rootfs_overlays,
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
