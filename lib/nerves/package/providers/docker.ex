defmodule Nerves.Package.Providers.Docker do
  @behaviour Nerves.Package.Provider

  alias Nerves.Package.Artifact

  @version "~> 1.12 or ~> 1.12.0-rc2"
  @config "~/.nerves/provider/docker"
  @tag "nervesproject/nerves_system_br:0.8.0"

  @sh "/bin/sh"
  @bash "/bin/bash"

  @artifact_script_nerves "scripts/docker/nerves_system_br/noninteractive-build.sh"
  @artifact_script_docker "/nerves/noninteractive-build.sh"

  @label "org.nerves-project.nerves_system_br=1.0"
  @dockerfile File.cwd!
              |> Path.join("template/Dockerfile")
  @working_dir "/nerves/build"

  def artifact(pkg, toolchain, _opts) do
    container = preflight(pkg)
    artifact_name = Artifact.name(pkg, toolchain)

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "build.log")
    stream = IO.stream(pid, :line)

    container_ensure_started(container)

    :ok = create_build(pkg, container, stream)
    :ok = make(container, stream)
    :ok = make_artifact(artifact_name, container, stream)
    :ok = copy_artifact(pkg, toolchain, container, stream)

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
        id = :crypto.strong_rand_bytes(16) |> Base.encode64 |> binary_part(0, 16)
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

    Nerves.Utils.Shell.info "Starting Docker Build...(this may take a while)"
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
        Docker provider encountered an error.
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
        Docker provider encountered an error.
        See build.log for more details.
        """
    end
  end

  defp make_artifact(name, container, stream) do
    Nerves.Utils.Shell.info "Compressing artifact"
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
        Docker provider encountered an error.
        See build.log for more details.
        """
    end
  end

  defp copy_artifact(pkg, toolchain, container, stream) do
    Nerves.Utils.Shell.info "Copying artifact to host"
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
        Docker provider encountered an error.
        See build.log for more details.
        """
    end

    base_dir = Artifact.base_dir(pkg)
    tar_file = Path.join(base_dir, "#{Artifact.name(pkg, toolchain)}.tar.gz")

    if File.exists?(tar_file) do
      dir = Artifact.dir(pkg, toolchain)
      File.mkdir_p(dir)

      cwd = base_dir
      |> String.to_char_list

      String.to_char_list(tar_file)
      |> :erl_tar.extract([:compressed, {:cwd, cwd}])

      File.rm!(tar_file)
    else
      Mix.raise "Docker provider expected artifact to exist at #{tar_file}"
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
    Nerves.Utils.Shell.info "Creating Docker container #{name}"
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
        Mix.raise "Docker provider encountered error: #{error}"
      {<<"Cannot connect to the Docker daemon", _tail :: binary>>, _} ->
        Mix.raise "Unable to connect to docker daemon"
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
        Mix.raise "Unable to connect to docker daemon"
      {_, 0} ->
        true
    end
  end

  defp docker_image_create(dockerfile, tag) do
    cmd = "docker"
    path = Path.dirname(dockerfile)
    args = ["build", "--tag", "#{tag}", path]
    Nerves.Utils.Shell.info "Docker provider needs to create the image."
    if Mix.shell.yes?("Continue?") do
      case Mix.Nerves.Utils.shell(cmd, args) do
        {_, 0} -> :ok
        _ -> Mix.raise "Could not create docker volume nerves_cache"
      end
    else
      Mix.raise "Unable to use docker provider without image"
    end
  end

  defp cache_volume? do
    cmd = "docker"
    args = ["volume", "ls", "-f", "name=nerves_cache", "-q"]
    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {<<"nerves_cache", _tail :: binary>>, 0} ->
        true
        {<<"Cannot connect to the Docker daemon", _tail :: binary>>, _} ->
          Mix.raise "Unable to connect to docker daemon"
      _ ->
        false
    end
  end

  defp cache_volume_create do
    cmd = "docker"
    args = ["volume", "create", "--name", "nerves_cache"]
    case System.cmd(cmd, args) do
      {_, 0} -> :noop
      _ -> Mix.raise "Could not create docker volume nerves_cache"
    end
  end

  defp container_ensure_started(name) do
    cmd = "docker"
    args = ["start", name]
    case System.cmd(cmd, args) do
      {_, 0} -> :noop
      {error, _} -> Mix.raise """
        Could not start Docker container #{name}
        Reason: #{error}
        """
    end
  end

  defp container_stop(name) do
    cmd = "docker"
    args = ["stop", name]
    case System.cmd(cmd, args) do
      {_, 0} -> :noop
      {error, _} -> Mix.raise """
        Could not stop Docker container #{name}
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
end
