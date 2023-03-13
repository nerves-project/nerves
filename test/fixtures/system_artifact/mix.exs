defmodule SystemArtifact.MixProject do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project() do
    [
      app: :system,
      version: @version,
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      deps: deps()
    ]
  end

  defp nerves_package() do
    [
      type: :system_artifact,
      build_runner: Nerves.Artifact.BuildRunners.Local,
      platform: SystemPlatform,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      artifact_sites: [
        {:github_releases, "nerves-project/bogus"}
      ],
      checksum: package_files()
    ]
  end

  defp deps() do
    [
      {:nerves, path: System.get_env("NERVES_PATH") || "../../../"},
      {:system_platform, path: "../system_platform"}
    ]
  end

  defp package_files() do
    [
      "mix.exs",
      "nerves_defconfig",
      "VERSION"
    ]
  end
end
