defmodule ToolchainPlatform.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
    |> File.read!
    |> String.trim

  def project do
    [
      app: :toolchain_platform,
      version: @version,
      nerves_package: nerves_package(),
      deps: deps()
    ]
  end

  defp nerves_package do
    [
      type: :toolchain_platform,
      checksum: package_files()
    ]
  end

  defp deps do
    []
  end

  defp package_files do
    [
      "mix.exs",
      "env.exs",
      "lib",
      "VERSION"
    ]
  end
end

defmodule ToolchainPlatform.Fixture do
  use Nerves.Package.Platform

  alias Nerves.Artifact

  def bootstrap(_pkg) do
    System.put_env("NERVES_BOOTSTRAP_SYSTEM", "1")
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

  def clean(pkg) do
    Artifact.build_path(pkg)
    |> File.rm_rf()
  end
end
