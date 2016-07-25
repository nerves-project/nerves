defmodule Nerves.Package.Providers.Docker do
  use Nerves.Package.Provider

  @version "~> 1.12 or 1.12.0-rc2"
  @config "~/.nerves/provider/docker"

  def artifact(pkg, toolchain) do
    _ = host_check()
    IO.inspect toolchain
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
