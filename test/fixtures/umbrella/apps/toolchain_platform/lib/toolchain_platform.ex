defmodule ToolchainPlatform do
  @moduledoc false
  @behaviour Nerves.Artifact.BuildRunner
  @behaviour Nerves.Package.Platform

  alias Nerves.Artifact

  @impl Nerves.Package.Platform
  def bootstrap(_pkg) do
    System.put_env("NERVES_BOOTSTRAP_TOOLCHAIN", "1")
    :ok
  end

  @impl Nerves.Artifact.BuildRunner
  def build(pkg, _toolchain, _opts) do
    build_path = Artifact.build_path(pkg)
    File.rm_rf!(build_path)
    File.mkdir_p!(build_path)

    build_path
    |> Path.join("file")
    |> File.touch()

    {:ok, build_path}
  end

  @impl Nerves.Package.Platform
  def build_path_link(pkg) do
    Artifact.build_path(pkg)
  end

  @impl Nerves.Artifact.BuildRunner
  def archive(pkg, _toolchain, _opts) do
    build_path = Artifact.build_path(pkg)
    name = Artifact.download_name(pkg) <> Artifact.ext(pkg)
    Nerves.Utils.File.tar(build_path, name)
    {:ok, Path.join(File.cwd!(), name)}
  end

  @impl Nerves.Artifact.BuildRunner
  def clean(pkg) do
    Artifact.build_path(pkg)
    |> File.rm_rf()

    :ok
  end
end
