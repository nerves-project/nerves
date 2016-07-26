defmodule Nerves.Package.Providers.Docker do
  use Nerves.Package.Provider

  alias Nerves.Package.Artifact

  @version "~> 1.12 or ~> 1.12.0-rc2"
  @config "~/.nerves/provider/docker"
  @machine "nerves_system_br"
  @cmd "/bin/sh"
  @script "/nerves/env/platform/scripts/build_artifact.sh"

  def artifact(pkg, toolchain) do
    _ = host_check()
    _ = config_check()

    platform = pkg.platform
    if Code.ensure_loaded?(platform) do
      build_paths = platform.build_paths(pkg)
      {_, _, platform_target} = Enum.find(build_paths, fn({type, _, _}) -> type == :platform end)
      args = [@machine, @cmd, @script,
        Artifact.name(pkg, toolchain),
        platform_target,
        Path.join(target, pkg.platform_config[:defconfig]),
        "/nerves/o/#{pkg.app}",
        Artifact.base_dir]
      args =
        |> Enum.reduce(build_paths, fn({_, host,target}, acc) ->
          ["-v" | ["#{host}:#{target}" | acc]]
        end)
      args = ["-v" | ["nerves_cache:/nerves/cache" | args]]
      args = ["-v" | ["#{Artifact.base_dir}:/nerves/host/artifacts" | args]]
      args = ["run" | ["-t" | args]]
      args_string = Enum.join(args, " ")
      Mix.Nerves.Utils.shell("docker", args, platform.stream)
      # File in Artifact.base_dir/Artifact.name(pkg, toolchain)
    else
      Nerves.Shell.info "#{platform} not loaded"
    end
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

  defp config_check() do
    # Check for the Cache Volume
    unless cache_volume? do
      cache_volume_create
    end
    :ok
  end

  defp cache_volume? do
    cmd = "docker"
    args = ["volume", "ls", "-f", "name=nerves_cache", "-q"]
    System.cmd(cmd, args)
      {"", 0} ->
        false
      {<<"nerves_cache", _tail :: binary>>} ->
        true
    end
  end

  defp cache_volume_create do
    cmd = "docker"
    args = ["volume", "create", "--name", "nerves_cache"]
    case System.cmd(cmd, args) do
      {_, 0} ->
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
