defmodule Nerves.Artifact.Resolver do
  @moduledoc """
  Downloads an artifact from a remote http location.
  """

  alias Nerves.Artifact

  require Logger

  @doc """
  Download the artifact from an http location
  """
  def get(pkg, [{location, opts} | locations]) do
    Nerves.Utils.Shell.info("  => Downloading #{location}")

    {:ok, pid} = Nerves.Utils.HTTPClient.start_link()

    query_params = Keyword.get(opts, :query_params, %{})

    uri =
      location
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(query_params))

    result = Nerves.Utils.HTTPClient.get(pid, uri, opts)
    Nerves.Utils.HTTPClient.stop(pid)

    result(result, pkg, locations)
  end

  def get(_pkg, _) do
    {:error, "No Locations"}
  end

  defp result({:ok, body}, pkg, _) do
    file = Artifact.download_path(pkg)
    File.mkdir_p(Nerves.Env.download_dir())
    File.write(file, body)

    case Nerves.Utils.File.validate(file) do
      :ok ->
        {:ok, file}

      {:error, reason} ->
        File.rm(file)
        {:error, reason}
    end
  end

  defp result({:error, reason}, _, []) do
    {:error, reason}
  end

  defp result(_, pkg, locations) do
    get(pkg, locations)
  end
end
