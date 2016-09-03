defmodule Nerves.Package.Providers.Docker do
  @behaviour Nerves.Package.Provider

  alias Nerves.Package.Artifact

  @version "~> 1.12 or ~> 1.12.0-rc2"
  @config "~/.nerves/provider/docker"
  @machine "nerves_system_br"

  @sh "/bin/sh"
  @bash "/bin/bash"

  @artifact_script "/nerves/env/platform/scripts/build-artifact.sh"
  @create_build "/nerves/env/platform/create-build.sh"

  @label "org.nerves-project.nerves_system_br=1.0"
  @dockerfile File.cwd!
              |> Path.join("template")

  def artifact(pkg, toolchain, _opts) do
    _ = host_check()
    _ = config_check()

    build_paths = build_paths(pkg)
    platform_config = pkg.config[:platform_config][:defconfig]
    base_dir = Artifact.base_dir(pkg)
    {_, _, platform_target} = Enum.find(build_paths, fn({type, _, _}) -> type == :platform end)
    args = [@machine, @sh, @artifact_script,
      Artifact.name(pkg, toolchain),
      platform_target,
      Path.join("/nerves/env/#{pkg.app}", platform_config),
      "/nerves/o/#{pkg.app}",
      "/nerves/host/artifacts"]
    args =
      Enum.reduce(build_paths, args, fn({_, host,target}, acc) ->
        ["-v" | ["#{host}:#{target}" | acc]]
      end)
    args = ["-v" | ["nerves_cache:/nerves/cache" | args]]
    args = ["-v" | ["#{base_dir}:/nerves/host/artifacts" | args]]
    args = ["run" | ["--rm" | ["-t" | args]]]

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "build.log")
    stream = IO.stream(pid, :line)
    Nerves.Utils.Shell.info "Docker provider starting..."
    case Mix.Nerves.Utils.shell("docker", args, stream) do
      {_result, 0} ->
        :ok
      {_result, _} ->
        Mix.raise """
        Docker provider encountered an error. See build.log for more details
        """
    end

    # File in Artifact.base_dir/Artifact.name(pkg, toolchain)
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

  def shell(_pkg) do
    #args = [@machine, @bash, @create_build]

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
      _ -> error_not_installed
    end
  end

  defp config_check do
    # Check for the Cache Volume
    unless cache_volume? do
      cache_volume_create
    end

    unless docker_image? do
      docker_image_create
    end
    :ok
  end

  defp docker_image? do
    cmd = "docker"
    args = ["images", "-f", "label=#{@label}", "-q"]
    case System.cmd(cmd, args) do
      {"", _} ->
        false
      {_, 0} ->
        true
    end
  end

  defp docker_image_create do
    cmd = "docker"
    args = ["build", "--label", @label, "--tag", "nerves_system_br:latest", @dockerfile]
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
    case System.cmd(cmd, args) do
      {<<"nerves_cache", _tail :: binary>>, 0} ->
        true
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
