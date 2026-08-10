# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloader.Prefix do
  @moduledoc false

  alias Nerves.HTTPClient
  alias Nerves.MixUtils

  @doc """
  Build a download plan for a prefix (direct URL) site (phase 1, pure).

  Returns `{module, plan}` or `nil`.
  """
  @spec plan(tuple(), String.t(), String.t()) :: {module(), map()} | nil
  def plan({:prefix, url}, version, artifact_filename) do
    plan({:prefix, url, []}, version, artifact_filename)
  end

  def plan({:prefix, base_url, opts}, _version, artifact_filename) do
    base_uri = URI.parse(base_url) |> URI.append_path("/#{artifact_filename}")

    uri =
      case Keyword.get(opts, :query_params) do
        nil -> base_uri
        "" -> base_uri
        query_params -> URI.append_query(base_uri, URI.encode_query(query_params))
      end

    headers = Keyword.get(opts, :headers, [])

    {__MODULE__, %{uri: uri, headers: headers, artifact_filename: artifact_filename}}
  end

  def plan(_site, _version, _artifact_filename), do: nil

  @doc """
  Execute a single prefix download plan (phase 2, HTTP).
  """
  @spec download(map(), String.t()) :: :ok | {:error, term()}
  def download(plan, dest_path) do
    MixUtils.info("  => Trying #{uri_log_target(plan.uri)}")

    HTTPClient.download(plan.uri, dest_path, headers: plan.headers)
  end

  defp uri_log_target(%URI{host: host}) when is_binary(host) and host != "", do: host
  defp uri_log_target(%URI{} = uri), do: URI.to_string(uri)
end
