defmodule Extra.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
    |> File.read!
    |> String.trim

  def project do
    [ 
      app: :extra,
      version: @version,
      compilers: Mix.compilers ++ [:nerves_package],
      nerves_package: nerves_package(),
      deps: deps()
    ]
  end

  defp nerves_package do
    [
      type: :host,
      platform: ExtraPlatform,
      platform_config: [],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      {:nerves, path: "../../../"}
    ]
  end

  defp package_files do
    [
      "mix.exs",
      "VERSION"
    ]
  end
end

defmodule ExtraPlatform do
  use Nerves.Package.Platform

  alias Nerves.Artifact

  def bootstrap(_pkg) do
    System.put_env("NERVES_BOOTSTRAP_EXTRA", "1")
    :ok
  end

  def build(pkg, _toolchain, _opts) do
    build_path = Artifact.build_path(pkg)
    File.rm_rf!(build_path)
    File.mkdir_p!(build_path)
    
    build_path
    |> Path.join("file")
    |> File.touch()

    {:ok, build_path}
  end

  def build_path_link(pkg) do
    Artifact.build_path(pkg)
  end

  def archive(pkg, _toolchain, _opts) do
    build_path = Artifact.build_path(pkg)
    name = Artifact.download_name(pkg) <> Artifact.ext(pkg)
    Nerves.Utils.File.tar(build_path, name)
    {:ok, Path.join(File.cwd!, name)}
  end

  def clean(_pkg) do
    :ok
  end

end
