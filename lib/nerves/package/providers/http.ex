defmodule Nerves.Package.Providers.HTTP do
  @moduledoc """
  Downloads an artifact from a remote http location.
  """

  @behaviour Nerves.Package.Provider

  alias Nerves.Package.Artifact
  require Logger

  @doc """
  Download the artifact from an http location
  """
  def artifact(pkg, toolchain, _opts) do
    artifact = "#{Artifact.name(pkg, toolchain)}.#{Artifact.ext(pkg)}"
    urls = pkg.config[:artifact_url]
    dest = Artifact.dir(pkg, toolchain)

    get(artifact, urls)
    |> unpack(artifact, dest)
  end

  def artifact(pkg, _toolchain) do
    Logger.debug "#{__MODULE__}: artifact: #{inspect pkg}"
  end

  def clean(_pkg) do
    :ok
  end

  defp get(artifact, urls) do
    cache_file = cache_file(artifact)
    if File.exists?(cache_file) do
      {:ok, cache_file}
    else
      download(artifact, urls)
    end
  end

  defp download(artifact, [location | locations]) do
    shell_info "Downloading Artifact #{artifact}", """
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

  defp download(_artifact, _) do
    shell_info "No Available Locations"
    {:error, :nocache}
  end

  defp result({:ok, body}, artifact, _) do
    shell_info "Artifact #{artifact} Downloaded"
    file = cache_file(artifact)
    File.write(file, body)
    {:ok, file}
  end
  defp result(_, _, []) do
    shell_info "No Available Locations"
    {:error, :nocache}
  end
  defp result(_, artifact, locations) do
    shell_info "Switching Location"
    download(artifact, locations)
  end

  defp unpack({:error, _} = error, _, _), do: error
  defp unpack({:ok, file}, artifact, destination) do
    shell_info "Unpacking #{artifact}", """
      To Destination:
        #{destination}
    """
    File.mkdir_p!(destination)
    {_, status} = System.cmd("tar", ["xf", file, "--strip-components=1", "-C", destination])
    case status do
      0 -> :ok
      _ -> :error
    end
  end

  defp shell_info(header, text \\ "") do
    Mix.Nerves.IO.shell_info(header, text, __MODULE__)
  end

  defp cache_file(artifact) do
    Nerves.Env.download_dir
    |> Path.join(artifact)
    |> Path.expand
  end
end
