defmodule Nerves.Package.Artifact.Resolver do
  @moduledoc """
  Downloads an artifact from a remote http location.
  """

  alias Nerves.Package.Artifact
  require Logger

  @doc """
  Download the artifact from an http location
  """
  def get(pkg, toolchain, _opts) do
    artifact = "#{Artifact.name(pkg, toolchain)}.#{Artifact.ext(pkg)}"
    urls = pkg.config[:artifact_url]

    cache_file = cache_file(artifact)
    if File.exists?(cache_file) do
      Nerves.Utils.Shell.info("  => Cached #{cache_file}")
      {:ok, cache_file}
    else
      download(artifact, urls)
    end
  end

  defp download(artifact, [location | locations]) do
    Nerves.Utils.Shell.info("  => Downloading #{location}")

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
    {:error, :nocache}
  end

  defp result({:ok, body}, artifact, _) do
    file = cache_file(artifact)
    File.mkdir_p(Nerves.Env.download_dir())
    File.write(file, body)
    {:ok, file}
  end
  defp result(_, _, []) do
    {:error, :nocache}
  end
  defp result(_, artifact, locations) do
    download(artifact, locations)
  end

  defp cache_file(artifact) do
    Nerves.Env.download_dir()
    |> Path.join(artifact)
    |> Path.expand
  end
end
