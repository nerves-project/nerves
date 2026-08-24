defmodule NervesHostTools.MixProject do
  use Mix.Project

  @app :nerves_host_tools
  @version "0.1.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      deps: deps(),
      nerves: [
        source_fingerprint_files: [
          "Dockerfile",
          "nerves-artifact",
          "mix.exs",
          "bin/custom-host-tool"
        ],
        dockerfile: "Dockerfile",
        plan_callback: &plan_callback/1
      ]
    ]
  end

  def application do
    []
  end

  defp plan_callback(build_plan) do
    package = Nerves.BuildPlan.find_package(build_plan, @app)

    host_tuple =
      build_plan.config[:host_tuple]
      |> Nerves.TargetTuple.to_nerves_v1_host_tuple()
      |> case do
        :error -> Mix.raise("Unsupported host tuple: #{inspect(build_plan.config[:host_tuple])}")
        tuple -> tuple
      end

    archive_name = "#{@app}-#{host_tuple}-#{package.version}-#{package.source_fingerprint}.tar.gz"
    archive_path = Path.join(package.download_path, archive_name)

    package =
      Map.merge(package, %{
        download_validators: [:archive],
        downloads: [
          %{
            archive_path: archive_path,
            filename: archive_name,
            sites: [],
            version: package.version
          }
        ],
        extractors: [{:untar, source: archive_path, destination: package.artifact_path}]
      })

    build_plan
    |> Nerves.BuildPlan.replace_package(package)
    |> Nerves.BuildPlan.prepend_path(Path.join([package.artifact_path, "host", "bin"]))
  end

  defp deps do
    [
      {:cover_helper, path: "../../cover_helper", runtime: false},
      {:nerves, path: "../../../..", override: true, runtime: false}
    ]
  end
end
