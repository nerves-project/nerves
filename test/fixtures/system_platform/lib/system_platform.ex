defmodule SystemPlatform do
  @moduledoc false
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
    {:ok, Path.join(File.cwd!(), name)}
  end

  def clean(pkg) do
    Artifact.build_path(pkg)
    |> File.rm_rf()
  end
end
