# SPDX-FileCopyrightText: 2026 Thomas Winkler
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.BuildRunners.Container do
  @moduledoc """
  Produce a Nerves artifact using Apple's `container` CLI (github.com/apple/container).

  This is a port of `Nerves.Artifact.BuildRunners.Docker` that runs the build in
  a lightweight Linux VM managed by Apple's container tooling instead of Docker.
  Requires Apple Silicon and container CLI >= 1.0.0. Only supports
  `nerves_system_br` >= 1.28.0 (image runs as user `nerves`, working dir
  `/home/nerves/project`).

  For `type: :system` packages, Nerves selects this runner automatically on
  Apple Silicon Macs that have the `container` CLI installed (see `available?/0`);
  every other host keeps the stock selection (`Docker` on macOS without the CLI
  or on Intel, `Local` on Linux). Setting `build_runner:` in the package config
  still takes precedence.

  ## Images

  By default the official `ghcr.io/nerves-project/<platform>:<version>` image is
  pulled (multi-arch; runs natively as arm64 on Apple Silicon). A custom image
  can be configured like with the Docker build runner:

      build_runner_config: [
        container: {"Containerfile", "my_system:0.1.0"}
      ]

  An existing `docker: {...}` key (for the stock Docker build runner) is
  honored as a fallback, so cross-platform systems don't need to declare the
  same image twice; `container:` takes precedence when both are set.

  ## Resources

  Every `container run` boots its own VM whose defaults (4 CPUs / 1 GB RAM) are
  far too small for Buildroot. This runner therefore allocates all host cores
  and half the host RAM (minimum 8G) by default. Override via
  `build_runner_config` or environment variables:

      build_runner_config: [
        cpus: 8,
        memory: "24G",     # or :host to allocate all host RAM (e.g. WebKit builds)
        volume_size: "256G"
      ]

  Environment variables `NERVES_CONTAINER_CPUS`, `NERVES_CONTAINER_MEMORY` and
  `NERVES_CONTAINER_VOLUME_SIZE` take precedence over the config. The memory
  ceiling is cheap: Virtualization.framework only faults pages in as the VM
  actually uses them.

  ## Volumes and cache

  Like the Docker build runner, the build directory lives in a named volume
  (`<app>-<id>`, id stored at `ARTIFACT_DIR/.container_id`). Volumes are sparse
  EXT4 images — fast and case-sensitive, unlike virtiofs bind mounts. The host
  `NERVES_DL_DIR` is bind-mounted at `/nerves/dl` for the download cache and to
  copy the finished artifact back to the host.

  Unlike the Docker build runner, `nerves_system_br` is NOT bind-mounted at
  `/nerves/env/platform` directly: `create-build.sh` extracts the Buildroot
  tarball (full of symlinks) there, and GNU tar cannot create symlinks through
  apple/container's virtiofs (apple/container#1209). Instead a second named
  volume (`<app>-<id>-platform`) is mounted there, the host sources are
  bind-mounted read-only at `/nerves/env/platform-src`, and the runner rsyncs
  them into the volume before each build (preserving the extracted
  `buildroot*` tree).

  Fresh volumes are owned by root, so the runner chowns the build directory and
  platform directory to the image's `nerves` user before each build.
  """
  @behaviour Nerves.Artifact.BuildRunner

  import Nerves.Artifact.BuildRunners.Container.Utils

  alias Nerves.Artifact
  alias Nerves.Artifact.BuildRunners.Container

  @version_requirement ">= 1.0.0"
  @working_dir "/home/nerves/project"

  # GNU tar cannot create symlinks through virtiofs (apple/container#1209),
  # so create-build.sh must extract Buildroot into an EXT4 volume: sync the
  # bind-mounted platform sources into it, preserving the extracted tree.
  @sync_platform_cmd [
    "rsync",
    "-a",
    "--delete",
    "--exclude=/buildroot*",
    "/nerves/env/platform-src/",
    "/nerves/env/platform/"
  ]

  @doc """
  Whether this host can build with Apple containers: an Apple Silicon Mac with
  the `container` CLI installed. `Nerves.Artifact.build_runner/1` uses this to
  auto-select the runner for `type: :system` packages.
  """
  @spec available?() :: boolean()
  def available?() do
    match?({:unix, :darwin}, :os.type()) and
      match?("aarch64" <> _, to_string(:erlang.system_info(:system_architecture))) and
      is_binary(System.find_executable("container"))
  end

  @doc """
  Create an artifact for the package.

  Opts:
    `make_args:` - Extra arguments to be passed to make.
  """
  @impl Nerves.Artifact.BuildRunner
  def build(pkg, _toolchain, opts) do
    _ = preflight(pkg)

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: build_log_path())
    stream = IO.stream(pid, :line)

    :ok = sync_platform(pkg, stream)
    :ok = create_build(pkg, stream)
    :ok = make(pkg, stream, opts)
    Mix.shell().info("\n")
    :ok = make_artifact(pkg, stream)
    Mix.shell().info("\n")
    {:ok, path} = copy_artifact(pkg, stream)
    Mix.shell().info("\n")
    _ = Nerves.Utils.Stream.stop(pid)
    {:ok, path}
  end

  @impl Nerves.Artifact.BuildRunner
  def archive(pkg, _toolchain, _opts) do
    _ = preflight(pkg)

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "archive.log")
    stream = IO.stream(pid, :line)

    _ = make_artifact(pkg, stream)
    copy_artifact(pkg, stream)
  end

  @impl Nerves.Artifact.BuildRunner
  def clean(pkg) do
    existing = Container.Volume.existing_names()

    _ =
      for name <- [Container.Volume.name(pkg), Container.Volume.platform_name(pkg)],
          name in existing do
        Container.Volume.delete(name)
      end

    _ = File.rm_rf(Artifact.Cache.path(pkg))

    :ok
  end

  @doc """
  Connect to a system configuration shell in a container
  """
  @spec system_shell(Nerves.Package.t()) :: :ok
  def system_shell(pkg) do
    _ = preflight(pkg)
    {_, image} = config(pkg)

    opts = Enum.join(resource_args(pkg) ++ env() ++ mounts(pkg) ++ ssh_mount(), " ")
    shell = "container run --rm -it -w #{@working_dir} #{opts} #{image} /bin/bash"

    sync_platform = Enum.join(@sync_platform_cmd, " ")
    create_build = create_build_cmd(pkg) |> Enum.join(" ")

    exec_input = """
      echo -e '\\e[25F\\e[0J\\e[1;7m\\n  Preparing Nerves Shell  \\e[0m';\
      echo -e '\\e]0;Nerves Shell\\a';\
      echo \\\"PS1='\\e[1;7m Nerves \\e[0;1m \\W > \\e[0m'\\\" >> ~/.bashrc;\
      echo \\\"PS2='\\e[1;7m Nerves \\e[0;1m \\W ..\\e[0m'\\\" >> ~/.bashrc;\
      echo 'Updating build directory.';\
      echo 'This will take a while if it is the first time...';\
      #{sync_platform} >/dev/null;\
      #{create_build} >/dev/null;\
      echo -e '\\nUse \\e[33mctrl+d\\e[0m or \\e[33mexit\\e[0m to leave the container shell\\n';\
      exec /bin/bash\
    """

    case InteractiveCmd.shell(~s(#{shell} -c "#{exec_input}")) do
      {_, 0} -> :ok
      {_, status} -> Mix.raise("Nerves shell exited with status #{status}")
    end
  end

  defp preflight(pkg) do
    check_nerves_system_br_version!()
    # Container.Volume.id/1 side effects and creates an id if one doesn't exist
    _ = Container.Volume.id(pkg)
    name = Container.Volume.name(pkg)
    _ = host_check()
    _ = service_check()
    _ = remove_stale_containers(pkg)
    _ = config_check(pkg, name)
    _ = set_volume_permissions(pkg)
    name
  end

  # A container that terminated abnormally (host sleep/reboot, service stop,
  # killed CLI) survives `--rm` as a stopped entry and keeps its volume
  # attachments reserved — new VMs then fail to bootstrap with VZErrorDomain
  # "The storage device attachment is invalid". Remove such leftovers; refuse
  # to run while the volumes are attached to a container that is still running.
  defp remove_stale_containers(pkg) do
    volumes = [Container.Volume.name(pkg), Container.Volume.platform_name(pkg)]

    _ =
      for %{id: id, state: state} <- Container.Instance.using_volumes(volumes) do
        case state do
          "running" ->
            Mix.raise("""
            Container #{id} is running and holds the build volumes for
            #{pkg.app} — is another build already in progress? Stop it first:

                container stop #{id}
            """)

          _ ->
            shell_info("Removing stale build container #{id}")
            Container.Instance.delete(id)
        end
      end

    :ok
  end

  # Build Commands

  defp create_build_cmd(pkg) do
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("/nerves/env/#{pkg.app}", platform_config)
    ["/nerves/env/platform/create-build.sh", defconfig, @working_dir]
  end

  defp sync_platform(pkg, stream) do
    shell_info("Syncing platform sources into build volume")
    run(pkg, @sync_platform_cmd, stream)
  end

  defp create_build(pkg, stream) do
    cmd = create_build_cmd(pkg)
    shell_info("Starting Build... (this may take a while)")
    run(pkg, cmd, stream)
  end

  defp make(pkg, stream, opts) do
    make_args = Keyword.get(opts, :make_args, [])
    run(pkg, ["make" | make_args], stream)
  end

  defp make_artifact(pkg, stream) do
    name = Artifact.download_name(pkg)
    shell_info("Creating artifact archive")
    cmd = ["make", "system", "NERVES_ARTIFACT_NAME=#{name}"]
    run(pkg, cmd, stream)
  end

  defp copy_artifact(pkg, stream) do
    shell_info("Copying artifact archive to host")
    name = Artifact.download_name(pkg) <> Artifact.ext(pkg)
    cmd = ["cp", name, "/nerves/dl/#{name}"]

    run(pkg, cmd, stream)
    path = Artifact.download_path(pkg)
    {:ok, path}
  end

  # Helpers

  defp run(pkg, cmd, stream) do
    {_containerfile, image} = config(pkg)

    args =
      ["run", "--rm", "--progress", "none", "-w", @working_dir] ++
        resource_args(pkg) ++ env() ++ mounts(pkg) ++ ssh_mount() ++ [image | cmd]

    case Mix.Nerves.Utils.shell("container", args, stream: stream) do
      {_result, 0} ->
        :ok

      {_result, _} ->
        log_tail = end_of_build_log()

        Mix.raise("""
        The Nerves container build_runner encountered an error while building:

        -----
        #{log_tail}
        -----

        See #{build_log_path()}.
        #{hint_for(log_tail)}\
        """)
    end
  end

  @doc false
  @spec hint_for(String.t()) :: String.t()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def hint_for(output) do
    cond do
      output =~ "storage device attachment is invalid" ->
        """

        Hint: a leftover container is probably still holding the build
        volumes (interrupted build, host sleep/reboot). Check
        `container list --all` and remove leftovers with
        `container delete <id>`, then retry.
        """

      output =~ "No space left on device" ->
        """

        Hint: either the host disk is full or the build volume hit its size
        ceiling. Free space with `mix nerves.clean <app>` or
        `container volume delete <name>`; the ceiling is configurable via
        build_runner_config: [volume_size: "256G"].
        """

      output =~ "name resolution" or output =~ "Host is unreachable" or
          output =~ "unable to resolve host" ->
        """

        Hint: the container has no network access. See "macOS 15: Containers
        Have No Network" in the nerves_container README for the subnet fix.
        """

      output =~ "XPC connection error" or output =~ "apiserver is not running" ->
        """

        Hint: the container system service is not responding — try
        `container system start`.
        """

      output =~ "Killed signal" or
          (output =~ "ninja: build stopped" and not (output =~ "error:")) ->
        """

        Hint: a compiler was likely OOM-killed (typical for WebKit builds —
        the kill message often gets lost in parallel output). Re-running
        `mix compile` resumes where the build stopped. To fix it for good,
        lower the parallelism so jobs fit into the VM memory, e.g.
        NERVES_CONTAINER_CPUS=8 mix compile — or persist it via
        build_runner_config: [cpus: 8].
        """

      true ->
        ""
    end
  end

  # Fresh volumes are EXT4 images owned by root. Unlike Docker, Apple's
  # container does not initialize new volumes with the ownership of the
  # image's mount point, so the `nerves` build user cannot write to the
  # build directory until it is chowned once. The root-owned lost+found
  # directories would trip up rsync --delete and Buildroot's find calls.
  defp set_volume_permissions(pkg) do
    {_containerfile, image} = config(pkg)

    prep_cmd =
      "chown nerves:nerves #{@working_dir} /nerves/env/platform && " <>
        "rm -rf #{@working_dir}/lost+found /nerves/env/platform/lost+found"

    args =
      ["run", "--rm", "--progress", "none", "--uid", "0", "--gid", "0"] ++
        mounts(pkg) ++ [image, "sh", "-c", prep_cmd]

    case System.cmd("container", args, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, _} ->
        Mix.shell().info(output)

        Mix.raise("""
        The Nerves container build_runner could not prepare the build volumes:
        #{hint_for(output)}\
        """)
    end
  end

  defp resource_args(pkg) do
    config = pkg.config[:build_runner_config] || []

    cpus =
      System.get_env("NERVES_CONTAINER_CPUS") ||
        to_string(config[:cpus] || System.schedulers_online())

    memory = System.get_env("NERVES_CONTAINER_MEMORY") || config_memory(config[:memory])

    ["--cpus", cpus, "--memory", memory]
  end

  # :host allocates all host RAM (memory-hungry builds like WebKit); the
  # default is half the host RAM (minimum 8G). The ceiling is cheap either
  # way: Virtualization.framework only faults pages in as the VM uses them.
  defp config_memory(:host), do: "#{max(host_memory_gb(), 8)}G"
  defp config_memory(nil), do: "#{max(div(host_memory_gb(), 2), 8)}G"
  defp config_memory(memory), do: memory

  # Memoized — resource_args/1 runs once per container run, but the host
  # RAM size doesn't change mid-build.
  defp host_memory_gb() do
    case :persistent_term.get({__MODULE__, :host_memory_gb}, nil) do
      nil ->
        gb = read_host_memory_gb()
        :persistent_term.put({__MODULE__, :host_memory_gb}, gb)
        gb

      gb ->
        gb
    end
  end

  defp read_host_memory_gb() do
    case System.cmd("sysctl", ["-n", "hw.memsize"]) do
      {result, 0} ->
        result
        |> String.trim()
        |> String.to_integer()
        |> div(1024 * 1024 * 1024)

      _ ->
        16
    end
  end

  defp volume_size(pkg) do
    config = pkg.config[:build_runner_config] || []
    System.get_env("NERVES_CONTAINER_VOLUME_SIZE") || config[:volume_size]
  end

  defp env() do
    term =
      case System.get_env("TERM") do
        term when is_binary(term) and byte_size(term) > 0 -> term
        _ -> "xterm-256color"
      end

    ["--env", "TERM=#{term}"]
  end

  defp end_of_build_log() do
    {lines, _rc} = System.cmd("tail", ["-16", build_log_path()])
    lines
  end

  defp build_log_path() do
    File.cwd!()
    |> Path.join("build.log")
  end

  defp mounts(pkg) do
    system_br = Nerves.Env.package(:nerves_system_br)
    download_dir = Nerves.Env.download_dir() |> Path.expand()

    [
      "--env",
      "NERVES_BR_DL_DIR=/nerves/dl",
      "--mount",
      "type=volume,source=#{Container.Volume.name(pkg)},target=#{@working_dir}",
      "--mount",
      "type=volume,source=#{Container.Volume.platform_name(pkg)},target=/nerves/env/platform",
      "--mount",
      "type=bind,source=#{system_br.path},target=/nerves/env/platform-src,readonly",
      "--mount",
      "type=bind,source=#{pkg.path},target=/nerves/env/#{pkg.app}",
      "--mount",
      "type=bind,source=#{download_dir},target=/nerves/dl"
    ]
  end

  defp ssh_mount() do
    ssh_path = Path.expand("~/.ssh")
    ["--mount", "type=bind,source=#{ssh_path},target=/home/nerves/.ssh,readonly"]
  end

  defp check_nerves_system_br_version!() do
    vsn = Application.spec(:nerves_system_br)[:vsn]

    if vsn == nil or not Version.match?(to_string(vsn), ">= 1.28.0") do
      Mix.raise("""
      Nerves.Artifact.BuildRunners.Container requires nerves_system_br >= 1.28.0
      (images that run as the non-root `nerves` user).
      """)
    end

    :ok
  end

  defp host_check() do
    case System.cmd("container", ["--version"]) do
      {result, 0} ->
        check_version!(result)

      _ ->
        error_not_installed()
    end
  rescue
    ErlangError -> error_not_installed()
  end

  defp check_version!(version_output) do
    case parse_container_version(version_output) do
      {:ok, vsn} ->
        if Version.match?(vsn, @version_requirement) do
          :ok
        else
          error_invalid_version(vsn)
        end

      :error ->
        error_invalid_version(String.trim(version_output))
    end
  end

  defp service_check() do
    case System.cmd("container", ["system", "status"], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      _ ->
        shell_info("Starting container system service")

        # --enable-kernel-install avoids the interactive kernel-download
        # prompt on first start, which would hang a non-interactive shell.
        case Mix.Nerves.Utils.shell("container", ["system", "start", "--enable-kernel-install"]) do
          {_, 0} ->
            :ok

          _ ->
            Mix.raise("""
            The container system service is not running and could not be started.
            Try running `container system start` manually.
            """)
        end
    end
  end

  defp config_check(pkg, name) do
    {containerfile, tag} = config(pkg)

    existing = Container.Volume.existing_names()
    size = volume_size(pkg)

    _ =
      for volume_name <- [name, Container.Volume.platform_name(pkg)],
          volume_name not in existing do
        Container.Volume.create(volume_name, size)
      end

    if !Container.Image.exists?(tag) do
      Container.Image.pull(tag)

      if !Container.Image.exists?(tag) do
        Container.Image.create(containerfile, tag)
      end
    end

    :ok
  end

  defp config(pkg) do
    build_runner_config = pkg.config[:build_runner_config] || []

    {containerfile, tag} =
      build_runner_config[:container] || build_runner_config[:docker] ||
        default_container_config()

    containerfile =
      containerfile
      |> Path.relative_to_cwd()
      |> Path.expand()

    {containerfile, tag}
  end

  defp default_container_config() do
    [platform] = Nerves.Env.packages_by_type(:system_platform)
    containerfile = Path.join(platform.path, "support/docker/#{platform.app}")
    tag = "ghcr.io/nerves-project/#{platform.app}:#{platform.version}"
    {containerfile, tag}
  end

  @spec error_not_installed() :: no_return()
  defp error_not_installed() do
    Mix.raise("""
    Apple's container CLI is not installed on your machine.
    Please install container #{@version_requirement} from
    https://github.com/apple/container (requires Apple Silicon).
    """)
  end

  @spec error_invalid_version(Version.t() | String.t()) :: no_return()
  defp error_invalid_version(vsn) do
    Mix.raise("""
    Your version of container: #{vsn}
    does not meet the requirements: #{@version_requirement}
    """)
  end

  @doc false
  @spec parse_container_version(String.t()) :: {:ok, Version.t()} | :error
  def parse_container_version(output) do
    case Regex.run(~r/version (\d+\.\d+\.\d+)/, output) do
      [_, vsn] -> Version.parse(vsn)
      _ -> :error
    end
  end
end
