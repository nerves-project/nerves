defmodule Nerves.Package.Providers.HTTP do
  @moduledoc """
  Downloads an artifact from a remote http location.
  """

  @behaviour Nerves.Package.Provider

  alias Nerves.Utils.Shell
  alias Nerves.Package.Artifact
  require Logger

  @doc """
  Download the artifact from an http location
  """
  def artifact(pkg, toolchain, _opts) do
    artifact = "#{Artifact.name(pkg, toolchain)}.#{Artifact.ext(pkg)}"
    url = pkg.config[:artifact_url]
    dest = Artifact.dir(pkg, toolchain)

    download(artifact, url)
    |> unpack(artifact, dest)
  end

  def artifact(pkg, _toolchain) do
    Logger.debug "#{__MODULE__}: artifact: #{inspect pkg}"
  end

  # def shell(_pkg, _opts) do
  #   :ok
  # end
  #
  # def clean(_pkg, _opts) do
  #   :ok
  # end

  defp download(_artifact, []) do
    shell_info "No Available Locations"
    {:error, :nocache}
  end
  defp download(artifact, [location | locations]) do
    shell_info """

      Downloading Artifact:
        #{artifact}
      From Location:
        #{location}
    """
    {:ok, pid} = Nerves.Utils.HTTPClient.start_link()

    location =
      location
      |> URI.encode
      |> String.replace("+", "%2B")

    result = Nerves.Utils.HTTPClient.get(pid, location)
    Nerves.Utils.HTTPClient.stop(pid)

    result(result, artifact, locations)
  end

  defp result({:ok, body}, name, _) do
    shell_info "Artifact #{name} Downloaded"
    {:ok, body}
  end
  defp result(_, _, []) do
    shell_info "No Available Locations"
    {:error, :nocache}
  end
  defp result(_, name, locations) do
    shell_info "Switching Location"
    download(name, locations)
  end

  defp unpack({:error, _} = error, _, _), do: error
  defp unpack({:ok, tar}, artifact, destination) do
    shell_info """

      Unpacking Artifact:
        #{artifact}
      To Destination:
        #{destination}
    """
    tmp_path = Path.join(destination, ".tmp")
    File.mkdir_p!(tmp_path)
    tar_file = Path.join(tmp_path, artifact)
    File.write(tar_file, tar)

    System.cmd("tar", ["xf", artifact], cd: tmp_path)
    source =
      File.ls!(tmp_path)
      |> Enum.map(& Path.join(tmp_path, &1))
      |> Enum.find(&File.dir?/1)

    File.rm!(tar_file)
    File.cp_r(source, destination)
    File.rm_rf!(tmp_path)
    :ok
  end

  defp shell_info(text) do
    Shell.info(text, "Nerves.Package.Providers.HTTP")
  end
end
