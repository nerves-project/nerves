defmodule Mix.Tasks.Nerves.Artifact.Get do
  use Mix.Task

  alias Nerves.Artifact
  alias Nerves.Artifact.{Cache, Resolver}

  @moduledoc """
    Fetch the artifacts from one of the artifact_sites
    This task is typically called as part of the 
    Nerves.Bootstrap aliases during `mix deps.get`

    You can also call into this task by calling 
    `mix nerves.deps.get`

    # Example

      $ mix nerves.artifact.get
  """

  @shortdoc "Nerves get artifacts"

  def run(opts) do
    Mix.shell().info("Resolving Nerves artifacts...")

    Nerves.Env.packages()
    |> Enum.each(&get(&1.app, opts))
  end

  def get(app, _opts) do
    case Nerves.Env.package(app) do
      %Nerves.Package{type: type} when type in [:toolchain_platform, :system_platform] ->
        :noop

      %Nerves.Package{} = pkg ->
        # Check to see if the package path is set in the environment
        if Nerves.Artifact.env_var?(pkg) do
          path = System.get_env(Nerves.Artifact.env_var(pkg))
          Nerves.Utils.Shell.success("  Env #{app}")
          Nerves.Utils.Shell.success("      #{path}")
        else
          # Check the cache
          case Artifact.Cache.get(pkg) do
            nil ->
              get_artifact(pkg)

            _cache_path ->
              Nerves.Utils.Shell.success("  Cached #{app}")
          end
        end

      _ ->
        Nerves.Utils.Shell.warn("  Skipping #{app}")
    end
  end

  defp get_artifact(pkg) do
    archive = Artifact.download_path(pkg)
    Nerves.Utils.Shell.success("  Resolving #{pkg.app}")

    with true <- File.exists?(archive),
         :ok <- Nerves.Utils.File.validate(archive) do
      Nerves.Utils.Shell.info("  => Trying #{archive}")
      put_cache(pkg, archive)
    else
      _error ->
        File.rm(archive)
        resolvers = Artifact.expand_sites(pkg)
        get_artifact(pkg, resolvers)
    end
  end

  defp get_artifact(pkg, []), do: Nerves.Utils.Shell.warn("  Skipping #{pkg.app}")

  defp get_artifact(pkg, resolvers) do
    case Resolver.get(resolvers, pkg) do
      {:ok, archive} ->
        put_cache(pkg, archive)

      {:error, reason} ->
        Nerves.Utils.Shell.error("  => #{reason}")
    end
  end

  defp put_cache(pkg, archive) do
    checksum = Artifact.checksum(pkg)

    if checksum == Nerves.Artifact.checksum(pkg) do
      Cache.put(pkg, archive)
      Nerves.Utils.Shell.success("  => Success")
      :ok
    else
      Nerves.Utils.Shell.error("  => Error: Checksums do not match")
      :error
    end
  end
end
