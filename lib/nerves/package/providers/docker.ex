defmodule Nerves.Package.Providers.Docker do
  @moduledoc """
  Produce an artifact for a package using Docker.

  The Nerves Docker artifact provider will use docker to create the artifact
  for the package. The output in Mix will be limited to the headlines from the
  process and the full build log can be found in the file `build.log` located
  root of the package path.

  ## Images

  Docker containers will be created based off the image that is loaded.
  By default, containers will use the default image
  `nervesproject/nerves_system_br:latest`. Sometimes additional host tools
  are required to build a package. Therefore, packages can provide their own
  images by specifying it in the package config under `:provider_config`.
  the file is specified as a tuple `{"path/to/Dockerfile", tag_name}`.

  Example:

    provider_config: [
      docker: {"Dockerfile", "my_system:0.1.0"}
    ]

  ## Volumes and Cache

  Nerves will mount several volumes to the container for use in building
  the artifact.

  Mounted from the host:

    * `/nerves/env/<package.name>` - The package being built.
    * `/nerves/env/platform` - The package platform package.
    * `/nerves/host/artifacts` - The host artifact dir.

  Nerves will also mount the host NERVES_DL_DIR to save downloaded assets the
  build platform requires for producing the artifact.
  This is mounted at `/nerves/dl`. This volume can significally reduce build
  times but has potential for corruption. If you suspect that your build is
  failing due to a faulty downloaded cached data, you can manually mount
  the offending container and remove the file from this location or delete the
  entire dir.

  Nerves uses a docker volume to attach the build files. The volume name is
  defined as the package name and a unique id that is stored at
  `ARTIFACT_DIR/.docker_id`. The build directory is mounted to the container at
  `/nerves/build` and is configured as the current working directory.

  ## Cleanup

  Perodically, you may want to destroy all unused volumes to clean up.
  Please refer to the Docker documentation for more information on how to
  do this.

  When the provider is finished, the artifact is decompressed on the host at
  the packages defined artifact dir.
  """

  @behaviour Nerves.Package.Provider

  alias Nerves.Package.Artifact
  alias Nerves.Package.Provider.Docker
  import Docker.Utils

  @version "~> 1.12 or ~> 1.12.0-rc2 or ~> 17.0"
  @tag "nervesproject/nerves_system_br:latest"

  @dockerfile File.cwd!
              |> Path.join("template/Dockerfile")
  @working_dir "/nerves/build"

  @doc """
  Create an artifact for the package
  """
  @spec artifact(Nerves.Package.t, Nerves.Package.t, term) :: :ok
  def artifact(pkg, toolchain, _opts) do
    preflight(pkg)

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "build.log")
    stream = IO.stream(pid, :line)

    :ok = create_build(pkg, stream)
    :ok = make(pkg, stream)
    Mix.shell.info("\n")
    :ok = make_artifact(pkg, toolchain, stream)
    Mix.shell.info("\n")
    :ok = copy_artifact(pkg, toolchain, stream)
    Mix.shell.info("\n")
    _ = Nerves.Utils.Stream.stop(pid)
  end

  def clean(pkg) do
    Docker.Volume.name(pkg)
    |> Docker.Volume.delete()
    Artifact.base_dir(pkg)
    |> File.rm_rf
  end

  @doc """
  Connect to a system configuration shell in a Docker container
  """
  @spec system_shell(Nerves.Package.t) :: :ok
  def system_shell(pkg) do
    preflight(pkg)
    {_, image} = config(pkg)
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("/nerves/env/#{pkg.app}", platform_config)

    initial_input = [
      "echo Updating build directory.",
      "echo This will take a while if it is the first time...",
      "/nerves/env/platform/create-build.sh #{defconfig} #{@working_dir} >/dev/null",
    ]
    mounts = Enum.join(mounts(pkg), " ")
    Mix.Nerves.Shell.open("docker run --rm -it -w #{@working_dir} #{mounts} #{image}", initial_input)
  end

  defp preflight(pkg) do
    Docker.Volume.id(pkg) || Docker.Volume.create_id(pkg)
    name = Docker.Volume.name(pkg)
    _ = host_check()
    _ = config_check(pkg, name)
    name
  end

  # Build Commands

  defp create_build(pkg, stream) do
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("/nerves/env/#{pkg.app}", platform_config)
    cmd = [
      "/nerves/env/platform/create-build.sh",
      defconfig,
      @working_dir]
    shell_info "Starting Build... (this may take a while)"
    run(pkg, cmd, stream)
  end

  defp make(pkg, stream) do
    run(pkg, ["make"], stream)
  end

  defp make_artifact(pkg, toolchain, stream) do
    name = Artifact.name(pkg, toolchain)
    shell_info "Compressing artifact"
    cmd = [
      "make",
      "system",
      "NERVES_ARTIFACT_NAME=#{name}"]
    run(pkg, cmd, stream)
  end

  defp copy_artifact(pkg, toolchain, stream) do
    shell_info "Copying artifact to host"
    name = Artifact.name(pkg, toolchain)

    cmd = [
      "cp",
      "#{name}.tar.gz",
      "/nerves/host/artifacts/#{name}.tar.gz"]

    run(pkg, cmd, stream)

    base_dir = Artifact.base_dir(pkg)
    tar_file = Path.join(base_dir, "#{Artifact.name(pkg, toolchain)}.tar.gz")

    if File.exists?(tar_file) do
      dir = Artifact.dir(pkg, toolchain)
      File.rm_rf(dir)
      File.mkdir_p(dir)

      cwd = base_dir
      |> String.to_charlist

      String.to_charlist(tar_file)
      |> :erl_tar.extract([:compressed, {:cwd, cwd}])

      File.rm!(tar_file)
      :ok
    else
      Mix.raise "Nerves Docker provider expected artifact to exist at #{tar_file}"
    end
  end

  # Helpers

  defp run(pkg, cmd, stream) do
    {_dockerfile, image} = config(pkg)
    args = [
      "run",
      "--rm",
      "-w=#{@working_dir}",
      "-a", "stdout",
      "-a", "stderr"
      ] ++ mounts(pkg) ++ [image | cmd]
    case Mix.Nerves.Utils.shell("docker", args, stream: stream) do
      {_result, 0} ->
        :ok
      {_result, _} ->
        Mix.raise """
        Nerves Docker provider encountered an error.
        See build.log for more details.
        """
    end
  end

  defp mounts(pkg) do
    build_paths = build_paths(pkg)
    base_dir = Artifact.base_dir(pkg)
    build_volume = Docker.Volume.name(pkg)
    mounts = ["--env", "NERVES_BR_DL_DIR=/nerves/dl"]
    mounts =
      Enum.reduce(build_paths, mounts, fn({_, host,target}, acc) ->
        ["--mount", "type=bind,src=#{host},target=#{target}" | acc]
      end)
    mounts = ["--mount", "type=bind,src=#{base_dir},target=/nerves/host/artifacts" | mounts]
    mounts = ["--mount", "type=volume,src=#{Nerves.Env.download_dir()},target=/nerves/dl" | mounts]
    ["--mount", "type=volume,src=#{build_volume},target=#{@working_dir}" | mounts]
  end

  defp build_paths(pkg) do
    system_br = Nerves.Env.package(:nerves_system_br)
    [{:platform, system_br.path, "/nerves/env/platform"},
     {:package, pkg.path, "/nerves/env/#{pkg.app}"}]
  end

  defp host_check() do
    try do
      case System.cmd("docker", ["--version"]) do
        {result, 0} ->
          <<"Docker version ", vsn :: binary>> = result
          {:ok, requirement} = Version.parse_requirement(@version)
          {:ok, vsn} = parse_docker_version(vsn)
          unless Version.match?(vsn, requirement) do
            error_invalid_version(vsn)
          end
          :ok
        _ -> error_not_installed()
      end
    rescue
      ErlangError -> error_not_installed()
    end
  end

  defp config_check(pkg, name) do
    {dockerfile, tag} = config(pkg)

    # Check for the Cache Volume
    unless Docker.Volume.exists?(@cache_volume) do
      Docker.Volume.create(@cache_volume)
    end

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
      (pkg.config[:provider_config] || [])
      |> Keyword.get(:docker, {@dockerfile, @tag})

    dockerfile =
      dockerfile
      |> Path.relative_to_cwd
      |> Path.expand
    {dockerfile, tag}
  end

  defp error_not_installed do
    Mix.raise """
    Docker is not installed on your machine.
    Please install docker #{@version} or later
    """
  end

  defp error_invalid_version(vsn) do
    Mix.raise """
    Your version of docker: #{vsn}
    does not meet the requirements: #{@version}
    """
  end

  def parse_docker_version(vsn) do
    [vsn | _] = String.split(vsn, ",", parts: 2)
    Regex.replace(~r/(\.|^)0+(?=\d)/, vsn, "\\1")
    |> Version.parse
  end


end
