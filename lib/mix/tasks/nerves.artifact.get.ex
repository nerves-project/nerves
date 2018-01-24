defmodule Mix.Tasks.Nerves.Artifact.Get do
  use Mix.Task

  alias Nerves.Artifact
  alias Nerves.Artifact.{Cache, Resolver}

  def run(opts) do
    Mix.shell.info "Resolving Nerves artifacts..."
    Nerves.Env.packages()
    |> Enum.each(&get(&1.app, opts))
  end
  def get(app, _opts) do
    case Nerves.Env.package(app) do
      %Nerves.Package{type: type} when type in [:toolchain_platform, :system_platform] ->
        :noop
      %Nerves.Package{} = pkg ->
        case Artifact.Cache.get(pkg) do
          nil -> 
            sites = Artifact.expand_sites(pkg)
            get_artifact(pkg, sites)
          _cache_path -> 
            Nerves.Utils.Shell.success("  Cached #{app}")
        end
      _ -> 
        Nerves.Utils.Shell.warn("  Skipping #{app}")
    end
  end

  defp get_artifact(pkg, []), do: 
    Nerves.Utils.Shell.warn("  Skipping #{pkg.app} (missing url)")
  defp get_artifact(pkg, sites) do
    Nerves.Utils.Shell.success("  Resolving #{pkg.app}")
    
    case Resolver.get(pkg, sites) do
      {:ok, archive} ->
        checksum = Artifact.checksum(pkg)
        if checksum == Nerves.Artifact.checksum(pkg) do
          Cache.put(pkg, archive)
          Nerves.Utils.Shell.success("  => Success")
        else
          Nerves.Utils.Shell.error("  => Error: Checksums do not match")
        end
      {:error, reason} ->
        Nerves.Utils.Shell.error("  => #{reason}")
    end
  end
end
