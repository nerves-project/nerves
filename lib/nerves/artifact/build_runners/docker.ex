# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2017 Greg Mefford
# SPDX-FileCopyrightText: 2018 Frank Hunleth
# SPDX-FileCopyrightText: 2018 Matt Ludwigs
# SPDX-FileCopyrightText: 2020 Hideki TAKASE
# SPDX-FileCopyrightText: 2022 Jon Carstens
# SPDX-FileCopyrightText: 2024 Jon Ringle
#
# SPDX-License-Identifier: Apache-2.0
#
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
  `ghcr.io/nerves-project/nerves_system_br:latest`. Sometimes additional host tools
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

  # nerves_system_br v1.28.0 changed to a Docker image that moves the
  # project build directory and runs everything as a non-root user.
  defp new_docker_image?() do
    version_c = Application.spec(:nerves_system_br)[:vsn]
    version_c != nil and Version.match?(to_string(version_c), ">= 1.28.0")
  end

  defp working_dir() do
    if new_docker_image?() do
      "/home/nerves/project"
    else
      "/nerves/build"
    end
  end

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
    _ = preflight(pkg)

    cmd1 = create_build_cmd(pkg)
    cmd2 = make_cmd(pkg, opts)
    cmd3 = make_artifact_cmd(pkg)
    cmd4 = copy_artifact_cmd(pkg)

    cmd =
      Enum.join(cmd1, " ") <>
        " && " <>
        Enum.join(cmd2, " ") <>
        " && " <>
        Enum.join(cmd3, " ") <>
        " && " <>
        Enum.join(cmd4, " ")

    run(pkg, cmd)

    path = Artifact.download_path(pkg)
    {:ok, path}
  end

  @impl Nerves.Artifact.BuildRunner
  def archive(pkg, _toolchain, _opts) do
    cmd3 = make_artifact_cmd(pkg)
    cmd4 = copy_artifact_cmd(pkg)

    cmd =
      Enum.join(cmd3, " ") <>
        " && " <>
        Enum.join(cmd4, " ")

    run(pkg, cmd)
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

  Unsupported in >= OTP 26. However, the Docker env will still be created
  and a command output to IO which can be used manually.
  """
  @spec system_shell(Nerves.Package.t()) :: :ok
  def system_shell(pkg) do
    _ = preflight(pkg)
    {_, image} = config(pkg)

    mounts = Enum.join(mounts(pkg), " ")
    ssh_mount = Enum.join(ssh_mount(), " ")
    env_vars = Enum.join(env(), " ")

    shell =
      "docker run --rm -it -w #{working_dir()} #{env_vars} #{mounts} #{ssh_mount} #{image} /bin/bash"

    set_volume_permissions(pkg)

    create_build = create_build_cmd(pkg) |> Enum.join(" ")

    exec_input = [
      "echo -e '\\e[25F\\e[0J\\e[1;7m\\n  Preparing Nerves Shell  \\e[0m'",
      "echo -e '\\e]0;Nerves Shell\\a'",
      "echo \\\"PS1='\\e[1;7m Nerves \\e[0;1m \\W > \\e[0m'\\\" >> ~/.bashrc",
      "echo \\\"PS2='\\e[1;7m Nerves \\e[0;1m \\W ..\\e[0m'\\\" >> ~/.bashrc",
      "echo 'Updating build directory.'",
      "echo 'This will take a while if it is the first time...'",
      "#{create_build} >/dev/null",
      "echo -e '\\nUse \\e[33mctrl+d\\e[0m or \\e[33mexit\\e[0m to leave the container shell\\n'",
      "exec /bin/bash"
    ]

    Mix.Nerves.Shell.open(~s(#{shell} -c "#{Enum.join(exec_input, " ; ")}"))
  end

  defp preflight(pkg) do
    # Docker.Volume.id/1 side effects and creates an id if one doesn't exist
    _ = Docker.Volume.id(pkg)
    name = Docker.Volume.name(pkg)
    _ = host_check()
    _ = config_check(pkg, name)
    name
  end

  # Build Commands

  defp create_build_cmd(pkg) do
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("/nerves/env/#{pkg.app}", platform_config)
    ["/nerves/env/platform/create-build.sh", defconfig, working_dir()]
  end

  defp make_cmd(pkg, opts) do
    make_args = Keyword.get(opts, :make_args, [])
    ["make" | make_args]
  end

  defp make_artifact_cmd(pkg) do
    name = Artifact.download_name(pkg)
    ["make", "system", "NERVES_ARTIFACT_NAME=#{name}"]
  end

  defp copy_artifact_cmd(pkg) do
    name = Artifact.download_name(pkg) <> Artifact.ext(pkg)
    ["cp", name, "/nerves/dl/#{name}"]
  end

  # Helpers

  defp run(pkg, cmd) do
    cmd_script_name = "__run.sh"
    cmd_script_path = Path.join(Nerves.Env.download_dir(), cmd_script_name)

    File.write!(cmd_script_path, cmd)
    set_volume_permissions(pkg)

    {_dockerfile, image} = config(pkg)

    args =
      [
        "run",
        "--rm",
        "-w=#{working_dir()}",
        "-a",
        "stdout",
        "-a",
        "stderr"
      ] ++ env() ++ mounts(pkg) ++ ssh_mount() ++ [image]

    line = "docker  #{Enum.join(args, " ")} sh /nerves/dl/#{cmd_script_name}"

    Mix.Nerves.Shell.open(line)
    #    case Mix.Nerves.Utils.shell("docker", args, stream: stream) do
    #      {_result, 0} ->
    #        :ok
    #
    #      {_result, _} ->
    #        Mix.raise("""
    #        The Nerves Docker build_runner encountered an error while building:
    #
    #        -----
    #        #{end_of_build_log()}
    #        -----
    #
    #        See #{build_log_path()}.
    #        """)
    #    end
    #File.rm!(cmd_script_path)
  end

  defp set_volume_permissions(pkg) do
    if new_docker_image?() do
      :ok
    else
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
          "-w=#{working_dir()}"
        ] ++ env(:root) ++ mounts(pkg) ++ [image | ["chown", "#{uid()}:#{gid()}", working_dir()]]

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
  end

  defp env(), do: env(uid(), gid())
  defp env(:root), do: env(0, 0)

  defp env(uid, gid) do
    term =
      case System.get_env("TERM") do
        term when is_binary(term) and byte_size(term) > 0 -> term
        _ -> "xterm-256color"
      end

    ["--env", "UID=#{uid}", "--env", "GID=#{gid}", "--env", "TERM=#{term}"]
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
    ["--mount", "type=volume,src=#{build_volume},target=#{working_dir()}" | mounts]
  end

  defp ssh_mount() do
    ssh_path = Path.expand("~/.ssh")
    ["--mount", "type=bind,src=#{ssh_path},target=/home/nerves/.ssh,readonly"]
  end

  defp build_paths(pkg) do
    system_br = Nerves.Env.package(:nerves_system_br)

    [
      {:platform, system_br.path, "/nerves/env/platform"},
      {:package, pkg.path, "/nerves/env/#{pkg.app}"}
    ]
  end

  defp host_check() do
    case Nerves.Port.cmd("docker", ["--version"]) do
      {result, 0} ->
        <<"Docker version ", vsn::binary>> = result
        {:ok, vsn} = parse_docker_version(vsn)

        if !Version.match?(vsn, @version) do
          error_invalid_version(vsn)
        end

        :ok

      _ ->
        error_not_installed()
    end
  rescue
    ErlangError -> error_not_installed()
  end

  defp config_check(pkg, name) do
    {dockerfile, tag} = config(pkg)

    # Check for the Build Volume
    if !Docker.Volume.exists?(name) do
      Docker.Volume.create(name)
    end

    if !Docker.Image.exists?(tag) do
      Docker.Image.pull(tag)

      if !Docker.Image.exists?(tag) do
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
    tag = "ghcr.io/nerves-project/#{platform.app}:#{platform.version}"
    {dockerfile, tag}
  end

  @spec error_not_installed() :: no_return()
  defp error_not_installed() do
    Mix.raise("""
    Docker is not installed on your machine.
    Please install docker #{@version} or later
    """)
  end

  @spec error_invalid_version(Version.t()) :: no_return()
  defp error_invalid_version(vsn) do
    Mix.raise("""
    Your version of docker: #{vsn}
    does not meet the requirements: #{@version}
    """)
  end

  @spec parse_docker_version(String.t()) :: {:ok, Version.t()} | :error
  def parse_docker_version(vsn) do
    [vsn | _] = String.split(vsn, ",", parts: 2)

    Regex.replace(~r/(\.|^)0+(?=\d)/, vsn, "\\1")
    |> Version.parse()
  end
end
