# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule ArtifactPackageFixture.MixProject do
  use Mix.Project

  def project do
    [
      app: :artifact_package_fixture,
      version: "1.2.3",
      deps: [],
      nerves_package: [
        type: :system,
        source_fingerprint_files: ["mix.exs"],
        build_script: "custom-build",
        shell_setup_script: "custom-setup",
        shell_help: "custom-help",
        env: [{"CUSTOM", "value"}],
        artifact_sites: [{:prefix, "https://example.com/artifacts"}]
      ]
    ]
  end
end
