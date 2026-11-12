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

    _ =
      Nerves.build_plan()
      |> Nerves.ArtifactResolver.resolve()

    :ok
  end
end
