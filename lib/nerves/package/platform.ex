defmodule Nerves.Package.Platform do
  @moduledoc """
  Defines the Nerves package platform behaviour

  This behaviour is implemented on a module that would be used to construct
  an artifact for a nerves package. Nerves packages are prioritized to be
  compiled before any other dependencies, therefore, a package platform
  is useful for constructing host tools to be used during the elixir compile
  phase.

  You can implement both `Nerves.Package.Platform` and `Nerves.Artifact.BuildRunner`
  in the same module with the using macro.

  Here is a simple example that touches a file in the `Artifact.build_path`

  ```elixir
  defmodule SystemPlatform do
    use Nerves.Package.Platform

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

  ```
  """

  @doc """
   Bootstrap is called as the final phase of loading the Nerves environment.
   It is used typically for setting / unsetting any system environment
   variables. For example, if we were building a C cross compiler, we would
   use the bootstrap phase to override CC to point to our compiler.
  """
  @callback bootstrap(Nerves.Package.t()) :: :ok | {:error, error :: term}

  @doc """
  Build path link should return the location inside the `Artifact.build_path`
  that represents the final artifact. This is used to symlink the global
  artifact to the local build_path location.
  """
  @callback build_path_link(package :: Nerves.Package.t()) :: build_path_link :: String.t()

  defmacro __using__(_) do
    quote do
      @behaviour Nerves.Artifact.BuildRunner
      @behaviour Nerves.Package.Platform
    end
  end
end
