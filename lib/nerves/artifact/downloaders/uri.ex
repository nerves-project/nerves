# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloaders.URI do
  @moduledoc """
  Downloads an artifact from a remote http location.
  """
  @behaviour Nerves.Artifact.Downloader

  @impl Nerves.Artifact.Downloader
  def expand_site({:prefix, url}, _info) do
    {:ok, {url, []}}
  end

  def expand_site({:prefix, url, resolver_opts}, _info) do
    {:ok, {url, resolver_opts}}
  end

  def expand_site(_site_config, _info), do: :skip

  @impl Nerves.Artifact.Downloader
  def download(base_url, opts) do
    {dest_dir, opts} = Keyword.pop!(opts, :dest_dir)
    {download_names, opts} = Keyword.pop!(opts, :download_names)
    {query_params, opts} = Keyword.pop(opts, :query_params, %{})

    try_names(base_url, download_names, dest_dir, query_params, opts)
  end

  @impl Nerves.Artifact.Downloader
  def site_help() do
    [
      ~s({:prefix, "http://myserver.com/artifacts"}),
      ~s({:prefix, "http://myserver.com/artifacts", headers: [{"Authorization", "Basic: 1234567=="}]}),
      ~s({:prefix, "http://myserver.com/artifacts", query_params: %{"id" => "1234567"}}),
      ~s({:prefix, "file:///my_artifacts/"}),
      ~s({:prefix, "/users/my_user/artifacts/"})
    ]
  end

  defp try_names(_base_url, [], _dest_dir, _query_params, _opts) do
    {:error, "No artifact found at any supported extension"}
  end

  defp try_names(base_url, [name | rest], dest_dir, query_params, opts) do
    location = Path.join(base_url, name)
    Nerves.Utils.Shell.info("  => Trying #{location}")

    uri =
      location
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(query_params))

    dest_path = Path.join(dest_dir, name)

    case Nerves.Utils.HTTPClient.download(uri, dest_path, opts) do
      :ok ->
        {:ok, dest_path}

      {:error, _reason} when rest != [] ->
        try_names(base_url, rest, dest_dir, query_params, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
