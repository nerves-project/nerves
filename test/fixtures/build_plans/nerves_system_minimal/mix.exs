defmodule NervesSystemMinimal.MixProject do
  use Mix.Project

  @github_organization "nerves-project"
  @app :nerves_system_minimal
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      nerves_package: nerves_package(),
      description: description(),
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp nerves_package do
    [
      type: :system,
      artifact_sites: [
        {:github_releases, "#{@github_organization}/#{@app}"}
      ],
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      env: [
        {"TARGET_ARCH", "aarch64"},
        {"TARGET_CPU", "cortex_a53"},
        {"TARGET_OS", "linux"},
        {"TARGET_ABI", "gnu"},
        {"TARGET_GCC_FLAGS", "-mabi=lp64 -fstack-protector-strong -mcpu=cortex-a53 -fPIE -pie"}
      ],
      source_fingerprint_files: ["mix.exs"]
    ]
  end

  defp deps do
    [
      {:nerves, path: "../../../..", override: true, runtime: false},
      {:nerves_system_br, "1.34.1", runtime: false},
      {:nerves_toolchain_aarch64_nerves_linux_gnu, "~> 15.3.0", runtime: false}
    ]
  end

  defp description do
    "Nerves System - Minimal"
  end
end
