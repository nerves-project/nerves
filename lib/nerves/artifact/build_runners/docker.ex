defmodule Nerves.Artifact.BuildRunners.Docker do
  @moduledoc """
  Produce an artifact for a package using Docker.

  The Nerves Docker artifact build_runner will use docker to create the artifact
  for the package. The output in Mix will be limited to the headlines from the
  process and the full build log can be found in the file `build.log` located
  root of the package path.

  ## Images

  Docker containers will be created based off the image that is loaded.
  By default, containers will use the default image
  `nervesproject/nerves_system_br:latest`. Sometimes additional host tools
  are required to build a package. Therefore, packages can provide their own
  images by specifying it in the package config under `:build_runner_config`.
  the file is specified as a tuple `{"path/to/Dockerfile", tag_name}`.

  Example:

      build_runner_config: [
        docker: {"Dockerfile", "my_system:0.1.0"}
      ]

  ## Volumes and Cache

  Nerves will mount several volumes to the container for use in building
  the artifact.

  Mounted from the host:

    * `/nerves/env/<package.name>` - The package being built.
    * `/nerves/env/platform` - The package platform package.
    * `/nerves/host/artifacts` - The host artifact directory.

  Nerves will also mount the host NERVES_DL_DIR to save downloaded assets the
  build platform requires for producing the artifact.
  This is mounted at `/nerves/dl`. This volume can significantly reduce build
  times but has potential for corruption. If you suspect that your build is
  failing due to a faulty downloaded cached data, you can manually mount
  the offending container and remove the file from this location or delete the
  entire directory.

  Nerves uses a docker volume to attach the build files. The volume name is
  defined as the package name and a unique id that is stored at
  `ARTIFACT_DIR/.docker_id`. The build directory is mounted to the container at
  `/nerves/build` and is configured as the current working directory.

  ## Cleanup

  Periodically, you may want to destroy all unused volumes to clean up.
  Please refer to the Docker documentation for more information on how to
  do this.

  When the build_runner is finished, the artifact is decompressed on the host at
  the packages defined artifact directory.
  """
  @behaviour Nerves.Artifact.BuildRunner

  import Nerves.Artifact.BuildRunners.Docker.Utils

  alias Nerves.Artifact
  alias Nerves.Artifact.BuildRunners.Docker

  @version "~> 1.12 or ~> 1.12.0-rc2 or >= 17.0.0"

  @working_dir "/nerves/build"

  @doc """
  Create an artifact for the package

  Opts:
    `make_args:` - Extra arguments to be passed to make.

    For example:

    You can configure the number of parallel jobs that buildroot
    can use for execution. This is useful for situations where you may
    have a machine with a lot of CPUs but not enough ram.

      # mix.exs
      defp nerves_package do
        [
          # ...
          build_runner_opts: [make_args: ["PARALLEL_JOBS=8"]],
        ]
      end
  """
  @impl Nerves.Artifact.BuildRunner
  def build(pkg, _toolchain, opts) do
    preflight(pkg)

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: build_log_path())
    stream = IO.stream(pid, :line)

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
    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "archive.log")
    stream = IO.stream(pid, :line)

    make_artifact(pkg, stream)
    copy_artifact(pkg, stream)
  end

  @impl Nerves.Artifact.BuildRunner
  def clean(pkg) do
    Docker.Volume.name(pkg)
    |> Docker.Volume.delete()

    _ = File.rm_rf(Artifact.Cache.path(pkg))

    :ok
  end

  @doc """
  Connect to a system configuration shell in a Docker container
  """
  @spec system_shell(Nerves.Package.t()) :: :ok
  def system_shell(pkg) do
    preflight(pkg)
    {_, image} = config(pkg)
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("/nerves/env/#{pkg.app}", platform_config)

    initial_input = [
      "echo Updating build directory.",
      "echo This will take a while if it is the first time...",
      "/nerves/env/platform/create-build.sh #{defconfig} #{@working_dir} >/dev/null"
    ]

    mounts = Enum.join(mounts(pkg), " ")
    ssh_agent = Enum.join(ssh_agent(), " ")
    env_vars = Enum.join(env(), " ")

    cmd =
      "docker run --rm -it -w #{@working_dir} #{env_vars} #{mounts} #{ssh_agent} #{image} /bin/bash"

    set_volume_permissions(pkg)

    Mix.Nerves.Shell.open(cmd, initial_input)
  end

  defp preflight(pkg) do
    # Docker.Volume.id/1 side effects and creates an id if one doesn't exist
    Docker.Volume.id(pkg)
    name = Docker.Volume.name(pkg)
    _ = host_check()
    _ = config_check(pkg, name)
    name
  end

  # Build Commands

  defp create_build(pkg, stream) do
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("/nerves/env/#{pkg.app}", platform_config)
    cmd = ["/nerves/env/platform/create-build.sh", defconfig, @working_dir]
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
    set_volume_permissions(pkg)

    {_dockerfile, image} = config(pkg)

    args =
      [
        "run",
        "--rm",
        "-w=#{@working_dir}",
        "-a",
        "stdout",
        "-a",
        "stderr"
      ] ++ env() ++ mounts(pkg) ++ ssh_agent() ++ [image | cmd]

    case Mix.Nerves.Utils.shell("docker", args, stream: stream) do
      {_result, 0} ->
        :ok

      {_result, _} ->
        Mix.raise("""
        The Nerves Docker build_runner encountered an error while building:

        -----
        #{end_of_build_log()}
        -----

        See #{build_log_path()}.
        """)
    end
  end

  defp set_volume_permissions(pkg) do
    {_dockerfile, image} = config(pkg)

    # (chown)
    #   Set the permissions of the build volume
    #   to match those of the host user:group.
    # (--rm)
    #   Remove the container when finished.
    args =
      [
        "run",
        "--rm",
        "-w=#{@working_dir}"
      ] ++ env(:root) ++ mounts(pkg) ++ [image | ["chown", "#{uid()}:#{gid()}", @working_dir]]

    case Mix.Nerves.Utils.shell("docker", args) do
      {_result, 0} ->
        :ok

      {result, _} ->
        Mix.raise("""
        The Nerves Docker build_runner encountered an error while setting permissions:

        #{inspect(result)}
        """)
    end
  end

  defp env(), do: env(uid(), gid())
  defp env(:root), do: env(0, 0)

  defp env(uid, gid) do
    ["--env", "UID=#{uid}", "--env", "GID=#{gid}"]
  end

  defp uid() do
    {uid, _} = Nerves.Port.cmd("id", ["-u"])
    String.trim(uid)
  end

  defp gid() do
    {gid, _} = Nerves.Port.cmd("id", ["-g"])
    String.trim(gid)
  end

  defp end_of_build_log() do
    {lines, _rc} = Nerves.Port.cmd("tail", ["-16", build_log_path()])
    lines
  end

  defp build_log_path() do
    File.cwd!()
    |> Path.join("build.log")
  end

  defp mounts(pkg) do
    build_paths = build_paths(pkg)
    build_volume = Docker.Volume.name(pkg)
    download_dir = Nerves.Env.download_dir() |> Path.expand()
    mounts = ["--env", "NERVES_BR_DL_DIR=/nerves/dl"]

    mounts =
      Enum.reduce(build_paths, mounts, fn {_, host, target}, acc ->
        ["--mount", "type=bind,src=#{host},target=#{target}" | acc]
      end)

    mounts = ["--mount", "type=bind,src=#{download_dir},target=/nerves/dl" | mounts]
    ["--mount", "type=volume,src=#{build_volume},target=#{@working_dir}" | mounts]
  end

  defp ssh_agent() do
    ssh_auth_sock = System.get_env("SSH_AUTH_SOCK")
    ["-v", "#{ssh_auth_sock}:/ssh-agent", "-e", "SSH_AUTH_SOCK=/ssh-agent"]
  end

  defp build_paths(pkg) do
    system_br = Nerves.Env.package(:nerves_system_br)

    [
      {:platform, system_br.path, "/nerves/env/platform"},
      {:package, pkg.path, "/nerves/env/#{pkg.app}"}
    ]
  end

  defp host_check() do
    try do
      case Nerves.Port.cmd("docker", ["--version"]) do
        {result, 0} ->
          <<"Docker version ", vsn::binary>> = result
          {:ok, requirement} = Version.parse_requirement(@version)
          {:ok, vsn} = parse_docker_version(vsn)

          unless Version.match?(vsn, requirement) do
            error_invalid_version(vsn)
          end

          :ok

        _ ->
          error_not_installed()
      end
    rescue
      ErlangError -> error_not_installed()
    end
  end

  defp config_check(pkg, name) do
    {dockerfile, tag} = config(pkg)

    # Check for the Build Volume
    unless Docker.Volume.exists?(name) do
      Docker.Volume.create(name)
    end

    unless Docker.Image.exists?(tag) do
      Docker.Image.pull(tag)

      unless Docker.Image.exists?(tag) do
        Docker.Image.create(dockerfile, tag)
      end
    end

    :ok
  end

  defp config(pkg) do
    {dockerfile, tag} =
      (pkg.config[:build_runner_config] || [])
      |> Keyword.get(:docker, default_docker_config())

    dockerfile =
      dockerfile
      |> Path.relative_to_cwd()
      |> Path.expand()

    {dockerfile, tag}
  end

  defp default_docker_config() do
    [platform] = Nerves.Env.packages_by_type(:system_platform)
    dockerfile = Path.join(platform.path, "support/docker/#{platform.app}")
    tag = "nervesproject/#{platform.app}:#{platform.version}"
    {dockerfile, tag}
  end

  defp error_not_installed() do
    Mix.raise("""
    Docker is not installed on your machine.
    Please install docker #{@version} or later
    """)
  end

  defp error_invalid_version(vsn) do
    Mix.raise("""
    Your version of docker: #{vsn}
    does not meet the requirements: #{@version}
    """)
  end

  def parse_docker_version(vsn) do
    [vsn | _] = String.split(vsn, ",", parts: 2)

    Regex.replace(~r/(\.|^)0+(?=\d)/, vsn, "\\1")
    |> Version.parse()
  end
end
