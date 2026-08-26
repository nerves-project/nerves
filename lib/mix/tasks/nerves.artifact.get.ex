# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Get do
  @shortdoc "Downloads prebuilt Nerves package artifacts"
  @moduledoc """
  Downloads prebuilt Nerves package artifacts

  Set the `MIX_TARGET` to select which dependencies should be evaluated.
  """
  use Mix.Task
  alias Nerves.MixUtils

  @impl Mix.Task
  def run(_opts) do
    MixUtils.info("Checking for prebuilt Nerves artifacts...")

    # Route everything through Nerves.export_env/1 since that's the central
    # place for the download logic that includes appropriate callbacks
    # invocations.
    Nerves.export_env()

    :ok
  end
end
