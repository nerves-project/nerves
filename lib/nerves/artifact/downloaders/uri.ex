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

  @doc """
  Download the artifact from an http location
  """
  @impl Nerves.Artifact.Downloader
  def download({location, opts}, dest_path) do
    Nerves.Utils.Shell.info("  => Trying #{location}")

    {query_params, opts} = Keyword.pop(opts, :query_params, %{})

    uri =
      location
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(query_params))

    Nerves.Utils.HTTPClient.download(uri, dest_path, opts)
  end
end
