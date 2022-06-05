defmodule Nerves.System.BR do
  @moduledoc """
  Package builder for Buildroot-based Nerves systems
  """
  use Nerves.Package.Platform

  import Mix.Nerves.Utils
  alias Nerves.Artifact

  @doc """
  Called as the last step of bootstrapping the Nerves env.
  """
  @impl Nerves.Package.Platform
  def bootstrap(%{path: path}) do
    _ =
      path
      |> Path.join("nerves_env.exs")
      |> Code.require_file()

    :ok
  end

  @doc """
  Build the artifact
  """
  @impl Nerves.Artifact.BuildRunner
  def build(pkg, toolchain, opts) do
    {_, type} = :os.type()
    make(type, pkg, toolchain, opts)
  end

  @doc """
  Return the location in the build path to where the global artifact is linked.
  """
  @impl Nerves.Package.Platform
  def build_path_link(pkg) do
    Artifact.build_path(pkg)
  end

  @doc """
  Clean up all the build files
  """
  @impl Nerves.Artifact.BuildRunner
  def clean(pkg) do
    _ = Artifact.Cache.delete(pkg)

    _ = File.rm_rf(Artifact.build_path(pkg))

    Nerves.Env.package(:nerves_system_br)
    |> Map.get(:path)
    |> Path.join("buildroot*")
    |> Path.wildcard()
    |> Enum.each(&File.rm_rf(&1))
  end

  @doc """
  Create an archive of the artifact
  """
  @impl Nerves.Artifact.BuildRunner
  def archive(pkg, toolchain, opts) do
    {_, type} = :os.type()
    make_archive(type, pkg, toolchain, opts)
  end

  defp make(:linux, pkg, _toolchain, opts) do
    System.delete_env("BINDIR")
    dest = Artifact.build_path(pkg)

    script = Path.join(Nerves.Env.package(:nerves_system_br).path, "create-build.sh")
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("#{pkg.path}", platform_config)
    _ = shell(script, [defconfig, dest])

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "build.log")
    stream = IO.stream(pid, :line)

    make_args = Keyword.get(opts, :make_args, [])

    case shell("make", make_args, cd: dest, stream: stream) do
      {_, 0} -> {:ok, dest}
      {_error, _} -> {:error, Nerves.Utils.Stream.history(pid)}
    end
  end

  defp make(type, _pkg, _toolchain, _opts) do
    error_host_os(type)
  end

  defp make_archive(:linux, pkg, _toolchain, _opts) do
    name = Artifact.download_name(pkg)
    dest = Artifact.build_path(pkg)

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "archive.log")
    stream = IO.stream(pid, :line)

    case shell("make", ["system", "NERVES_ARTIFACT_NAME=#{name}"], cd: dest, stream: stream) do
      {_, 0} -> {:ok, Path.join(dest, name <> Artifact.ext(pkg))}
      {_error, _} -> {:error, Nerves.Utils.Stream.history(pid)}
    end
  end

  defp make_archive(type, _pkg, _toolchain, _opts) do
    error_host_os(type)
  end

  defp error_host_os(type) do
    {:error,
     """
     Local build_runner is not available for host system: #{type}
     Please use the Docker build_runner to build this package artifact
     """}
  end
end
