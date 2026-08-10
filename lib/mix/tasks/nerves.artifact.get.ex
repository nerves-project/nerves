# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Get do
  @shortdoc "Downloads prebuilt Nerves system and toolchain artifacts"
  @moduledoc """
  Downloads prebuilt Nerves system and toolchain artifacts.

  This task scans the project's dependencies for Nerves packages
  that have `:artifact_sites` configured, then downloads and extracts
  their precompiled artifacts.

  Artifacts are cached in `~/.nerves/dl/` (downloads) and
  `~/.nerves/artifacts/` (extracted).

  Resolution is type-agnostic: the host-specific artifact variant is
  tried first, falling back to portable. File extensions are not
  assumed — any `.tar.*` archive is accepted.

  It is not intended to be run manually. It is called as part of
  the `deps.get` alias set up by `nerves_bootstrap`.
  """
  use Mix.Task

  alias Nerves.ArtifactResolver
  alias Nerves.MixUtils

  @impl Mix.Task
  def run(_opts) do
    MixUtils.info("Checking for prebuilt Nerves artifacts...")

    _build_plan =
      Nerves.build_plan()
      |> ArtifactResolver.resolve()

    :ok
  end
end
