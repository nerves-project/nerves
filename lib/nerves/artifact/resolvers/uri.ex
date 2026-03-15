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

  @doc """
  Download the artifact from an http location
  """
  @impl Nerves.Artifact.Resolver
  def get({location, opts}) do
    Nerves.Utils.Shell.info("  => Trying #{location}")

    query_params = Keyword.get(opts, :query_params, %{})

    uri =
      location
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(query_params))

    Nerves.Utils.HTTPClient.get(uri, opts)
  end
end
