defmodule Nerves.Artifact.Resolvers.URI do
  @moduledoc """
  Downloads an artifact from a remote http location.
  """
  @behaviour Nerves.Artifact.Resolver

  @doc """
  Download the artifact from an http location
  """
  @impl Nerves.Artifact.Resolver
  def get({location, opts}) do
    Nerves.Utils.Shell.info("  => Trying #{location}")

    {:ok, pid} = Nerves.Utils.HTTPClient.start_link()

    query_params = Keyword.get(opts, :query_params, %{})

    uri =
      location
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(query_params))

    result = Nerves.Utils.HTTPClient.get(pid, uri, opts)
    Nerves.Utils.HTTPClient.stop(pid)

    result
  end
end
