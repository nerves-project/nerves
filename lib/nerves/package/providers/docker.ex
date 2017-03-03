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
  `nervesproject/nerves_system_br:0.8.0`. Sometimes additional host tools
  are required to build a package. Therefore, packages can provide their own
  images by specifying it in the package config under `:provider_config`.
  the file is specified as a tuple `{"path/to/Dockerfile", tag_name}`.

  Example:

    provider_config: [
      docker: {"Dockerfile", "my_system:0.1.0"}
    ]

  ## Containers

  Containers are created for each package / checksum combination and they are
  prefixed with a unique id. This allows the provider to build two similar
  packages for different applications at the same time without fighting
  over the same container. When the build has finished the container is
  stopped, but not removed. This allows you to manually start and attach
  to the container for debugging purposes.

  ## Volumes and Cache

  Nerves will mount several volumes to the container for use in building
  the artifact.

  Mounted from the host:

    * `/nerves/env/<package.name>` - The package being built.
    * `/nerves/env/platform` - The package platform package.
    * `/nerves/host/artifacts` - The host artifact dir.

  Nerves will also create and mount docker volume which is used to cache
  downloaded assets the build platform requires for producing the artifact.
  This is mounted at `/nerves/cache`. This volume can significally reduce build
  times but has potential for corruption. If you suspect that your build is
  failing due to a faulty downloaded cached data, you can manually mount
  the offending container and remove the file from this volume or delete the
  entire cache volume.

  Due to issues with building in host mounted volumes, the working directory
  is set to `/nerves/build` and is not mounted from the host.

  ## Cleanup

  Perodically, you may want to destroy all unused containers to clean up.
  Please refer to the Docker documentation for more information on how to
  do this.

  When the provider is finished, the artifact is decompressed on the host at
  the packages defined artifact dir.
  """

  @behaviour Nerves.Package.Provider

  alias Nerves.Package.Artifact

  @version "~> 1.12 or ~> 1.12.0-rc2 or ~> 17.0"
  @tag "nervesproject/nerves_system_br:0.8.0"

  @dockerfile File.cwd!
              |> Path.join("template/Dockerfile")
  @working_dir "/nerves/build"

  @doc """
  Create an artifact for the package
  """
  @spec artifact(Nerves.Package.t, Nerves.Package.t, term) :: :ok
  def artifact(pkg, toolchain, _opts) do
    container = preflight(pkg)
    artifact_name = Artifact.name(pkg, toolchain)

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "build.log")
    stream = IO.stream(pid, :line)

    container_ensure_started(container)

    :ok = create_build(pkg, container, stream)
    :ok = make(container, stream)
    Mix.shell.info("\n")
    :ok = make_artifact(artifact_name, container, stream)
    Mix.shell.info("\n")
    :ok = copy_artifact(pkg, toolchain, container, stream)
    Mix.shell.info("\n")
    _ = Nerves.Utils.Stream.stop(pid)
    container_stop(container)
  end

  # def shell(pkg, _opts) do
  #   _container = preflight(pkg)
  #   :ok
  # end
  #
  # def clean(_pkg, _opts) do
  #   :ok
  # end

  defp preflight(pkg) do
    checksum = Nerves.Package.checksum(pkg)

    id_file =
      Mix.Project.build_path
      |> Path.join("nerves/.docker_id")

    id =
      if File.exists?(id_file) do
        File.read!(id_file)
      else
        id = :crypto.strong_rand_bytes(16) |> Base.url_encode64 |> binary_part(0, 16)
        Path.dirname(id_file)
        |> File.mkdir_p!
        File.write!(id_file, id)
        id
      end

    name = "#{id}-#{pkg.app}-#{checksum}"

    _ = host_check()
    _ = config_check(pkg, name)

    name
  end

  defp create_build(pkg, container, stream) do
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("/nerves/env/#{pkg.app}", platform_config)

    shell_info "Starting Build... (this may take a while)"
    args = [
      "exec",
      "-i",
      container,
      "/nerves/env/platform/create-build.sh",
      defconfig,
      @working_dir]

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

  defp make(container, stream) do

    args = [
      "exec",
      "-i",
      container,
      "make"]

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

  defp make_artifact(name, container, stream) do
    shell_info "Compressing artifact"
    args = [
      "exec",
      "-i",
      container,
      "make",
      "system",
      "NERVES_ARTIFACT_NAME=#{name}"]

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

  defp copy_artifact(pkg, toolchain, container, stream) do
    shell_info "Copying artifact to host"
    name = Artifact.name(pkg, toolchain)

    args = [
      "exec",
      "-i",
      container,
      "cp",
      "#{name}.tar.gz",
      "/nerves/host/artifacts/#{name}.tar.gz"]

    case Mix.Nerves.Utils.shell("docker", args, stream: stream) do
      {_result, 0} ->
        :ok
      {_result, _} ->
        Mix.raise """
        Nerves Docker provider encountered an error.
        See build.log for more details.
        """
    end

    base_dir = Artifact.base_dir(pkg)
    tar_file = Path.join(base_dir, "#{Artifact.name(pkg, toolchain)}.tar.gz")

    if File.exists?(tar_file) do
      dir = Artifact.dir(pkg, toolchain)
      File.rm_rf(dir)
      File.mkdir_p(dir)

      cwd = base_dir
      |> String.to_char_list

      String.to_char_list(tar_file)
      |> :erl_tar.extract([:compressed, {:cwd, cwd}])

      File.rm!(tar_file)
      :ok
    else
      Mix.raise "Nerves Docker provider expected artifact to exist at #{tar_file}"
    end
  end

  defp build_paths(pkg) do
    system_br = Nerves.Env.package(:nerves_system_br)
    [{:platform, system_br.path, "/nerves/env/platform"},
     {:package, pkg.path, "/nerves/env/#{pkg.app}"}]
  end

  defp host_check() do
    case System.cmd("docker", ["--version"]) do
      {result, 0} ->
        <<"Docker version ", vsn :: binary>> = result
        [vsn | _] = String.split(vsn, ",", parts: 2)
        {:ok, requirement} = Version.parse_requirement(@version)
        {:ok, vsn} = Version.parse(vsn)
        unless Version.match?(vsn, requirement) do
          error_invalid_version(vsn)
        end
        :ok
      _ -> error_not_installed()
    end
  end

  defp config_check(pkg, name) do
    {dockerfile, tag} =
      (pkg.config[:provider_config] || [])
      |> Keyword.get(:docker, {@dockerfile, @tag})

    dockerfile =
      dockerfile
      |> Path.relative_to_cwd
      |> Path.expand

    # Check for the Cache Volume
    unless cache_volume?() do
      cache_volume_create()
    end

    unless docker_image?(tag) do
      docker_image_create(dockerfile, tag)
    end

    unless container?(name) do
      container_create(pkg, name, tag)
    end
    :ok
  end

  defp container?(name) do
    cmd = "docker"
    args = ["ps", "-a", "-f", "name=#{name}", "-q"]
    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {"", _} ->
        false
      {<<"Cannot connect to the Docker daemon", _tail :: binary>>, _} ->
        Mix.raise "Unable to connect to docker daemon"
      {_, 0} ->
        true
    end
  end

  defp container_create(pkg, name, tag) do
    shell_info "Creating Docker container #{name}"
    build_paths = build_paths(pkg)
    base_dir = Artifact.base_dir(pkg)

    args = [tag, "bash"]

    args =
      Enum.reduce(build_paths, args, fn({_, host,target}, acc) ->
        ["-v" | ["#{host}:#{target}" | acc]]
      end)
    args = ["-v" | ["nerves_cache:/nerves/cache" | args]]
    args = ["-v" | ["#{base_dir}:/nerves/host/artifacts" | args]]

    cmd = "docker"
    args = ["create", "-it", "--name", name , "-w", @working_dir | args]
    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {error, code} when code != 0 ->
        Mix.raise "Nerves Docker provider encountered error: #{error}"
      {<<"Cannot connect to the Docker daemon", _tail :: binary>>, _} ->
        Mix.raise "Nerves Docker provider is unable to connect to docker daemon"
      _ -> :ok
    end
  end

  defp docker_image?(tag) do
    cmd = "docker"
    args = ["images", "-q", "#{tag}", "-q"]
    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {"", _} ->
        false
      {<<"Cannot connect to the Docker daemon", _tail :: binary>>, _} ->
        Mix.raise "Nerves Docker provider is unable to connect to docker daemon"
      {_, 0} ->
        true
    end
  end

  defp docker_image_create(dockerfile, tag) do
    cmd = "docker"
    path = Path.dirname(dockerfile)
    args = ["build", "--tag", "#{tag}", path]
    shell_info "Create Image"
    if Mix.shell.yes?("The Nerves Docker provider needs to create the image.\nProceed? ") do
      case Mix.Nerves.Utils.shell(cmd, args) do
        {_, 0} -> :ok
        _ -> Mix.raise "Nerves Docker provider could not create docker volume nerves_cache"
      end
    else
      Mix.raise "Unable to use Nerves Docker provider without image"
    end
  end

  defp cache_volume? do
    cmd = "docker"
    args = ["volume", "ls", "-f", "name=nerves_cache", "-q"]
    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {<<"nerves_cache", _tail :: binary>>, 0} ->
        true
        {<<"Cannot connect to the Docker daemon", _tail :: binary>>, _} ->
          Mix.raise "Nerves Docker provider is unable to connect to docker daemon"
      _ ->
        false
    end
  end

  defp cache_volume_create do
    cmd = "docker"
    args = ["volume", "create", "--name", "nerves_cache"]
    case System.cmd(cmd, args) do
      {_, 0} -> :noop
      _ -> Mix.raise "Nerves Docker provider could not create docker volume nerves_cache"
    end
  end

  defp container_ensure_started(name) do
    cmd = "docker"
    args = ["start", name]
    case System.cmd(cmd, args) do
      {_, 0} -> :noop
      {error, _} -> Mix.raise """
        The Nerves Docker provider could not start Docker container #{name}
        Reason: #{error}
        """
    end
  end

  defp container_stop(name) do
    cmd = "docker"
    args = ["stop", name]
    case System.cmd(cmd, args) do
      {_, 0} -> :ok
      {error, _} -> Mix.raise """
        The Nerves Docker provider could not stop Docker container #{name}
        Reason: #{error}
        """
    end
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

  defp shell_info(header, text \\ "") do
    Mix.Nerves.IO.shell_info(header, text, __MODULE__)
  end
end
