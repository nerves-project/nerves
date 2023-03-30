defmodule Mix.Tasks.Nerves.Artifact.Get do
  @moduledoc false
  use Mix.Task

  alias Nerves.Artifact
  alias Nerves.Artifact.{Cache, Resolver}

  @impl Mix.Task
  def run(_opts) do
    Mix.shell().info("Checking for prebuilt Nerves artifacts...")

    Nerves.Env.packages()
    |> Enum.each(&get(&1.app))
  end

  @doc false
  @spec get(atom()) :: :ok
  def get(app) do
    case Nerves.Env.package(app) do
      %Nerves.Package{type: type} when type in [:toolchain_platform, :system_platform] ->
        :ok

      %Nerves.Package{} = pkg ->
        # Check to see if the package path is set in the environment
        cond do
          Nerves.Artifact.env_var?(pkg) ->
            path = System.get_env(Nerves.Artifact.env_var(pkg))
            Nerves.Utils.Shell.success("  Env #{app}")
            Nerves.Utils.Shell.success("      #{path}")

          # Check the cache
          cache_path = Artifact.Cache.get(pkg) ->
            Nerves.Utils.Shell.success("  Found #{app} in cache")
            Nerves.Utils.Shell.info("    #{cache_path}")

          true ->
            get_artifact(pkg)
        end

      _ ->
        Nerves.Utils.Shell.warn("  Skipping #{app}")
    end
  end

  defp get_artifact(pkg) do
    archive = Artifact.download_path(pkg)
    Nerves.Utils.Shell.success("  Checking #{pkg.app}...")

    with true <- File.exists?(archive),
         :ok <- Nerves.Utils.File.validate(archive) do
      Nerves.Utils.Shell.info("  => Trying #{archive}")
      put_cache(pkg, archive)
    else
      _error ->
        _ = File.rm(archive)
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
        Nerves.Utils.Shell.error("  => Prebuilt #{pkg.app} not found (#{reason})")
    end
  end

  defp put_cache(pkg, archive) do
    checksum = Artifact.checksum(pkg)

    if checksum == Nerves.Artifact.checksum(pkg) do
      _ = Cache.put(pkg, archive)
      Nerves.Utils.Shell.success("  => Success")
    else
      Nerves.Utils.Shell.error("  => Error: Checksums do not match")
    end
  end
end
