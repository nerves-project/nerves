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
        case Artifact.Cache.get(pkg) do
          nil ->
            resolvers = Artifact.expand_sites(pkg)
            Nerves.Utils.Shell.success("  Resolving #{pkg.app}")
            get_artifact(pkg, resolvers)

          _cache_path ->
            Nerves.Utils.Shell.success("  Cached #{app}")
        end

      _ ->
        Nerves.Utils.Shell.warn("  Skipping #{app}")
    end
  end

  defp get_artifact(pkg, []), do: Nerves.Utils.Shell.warn("  Skipping #{pkg.app}")

  defp get_artifact(pkg, resolvers) do
    case Resolver.get(resolvers, pkg) do
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
