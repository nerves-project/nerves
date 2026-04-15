# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Resolvers.URI do
  @moduledoc """
  Downloads an artifact from a remote http location.
  """
  @behaviour Nerves.Artifact.Resolver

  @impl Nerves.Artifact.Resolver
  def plan({:prefix, url}, version, artifact_filename) do
    plan({:prefix, url, []}, version, artifact_filename)
  end

  def plan({:prefix, url, opts}, _version, artifact_filename) do
    base_uri = URI.parse(url) |> URI.append_path("/#{artifact_filename}")

    uri =
      case Keyword.get(opts, :query_params) do
        nil -> base_uri
        "" -> base_uri
        query_params -> URI.append_query(base_uri, URI.encode_query(query_params))
      end

    headers = Keyword.get(opts, :headers, [])

    {__MODULE__, %{uri: uri, headers: headers}}
  end

  def plan(_site, _version, _artifact_filename), do: nil

  defp uri_log_target(%URI{host: host}) when is_binary(host) and host != "", do: host
  defp uri_log_target(%URI{} = uri), do: URI.to_string(uri)

  @impl Nerves.Artifact.Resolver
  def get(opts, dest_path) do
    Nerves.Utils.Shell.info("  => Trying #{uri_log_target(opts.uri)}")

    Nerves.Utils.HTTPClient.download(opts.uri, dest_path, headers: opts.headers)
  end
end
