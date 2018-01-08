defmodule Mix.Tasks.Nerves.Artifact.Get do
  use Mix.Task

  alias Nerves.Package.Artifact
  alias Nerves.Package.Artifact.Resolver

  def run(opts) do
    Mix.Project.config() |> IO.inspect
    Mix.shell.info "Resolving Nerves artifacts..."
    Nerves.Env.packages()
    |> Enum.each(&get(&1.app, opts))
  end
  def get(app, opts) do
    case Nerves.Env.package(app) do
      %Nerves.Package{provider: :noop} ->
        Nerves.Utils.Shell.warn("  Skipping #{app}")
      %Nerves.Package{config: config} = pkg ->
        url = config[:artifact_url]
        checksum = config[:artifact_checksum]
        get_artifact(pkg, url, checksum, opts)
      _ -> 
        Nerves.Utils.Shell.warn("  Skipping #{app}")
    end
  end
  defp get_artifact(pkg, nil, nil, _), do: 
    Nerves.Utils.Shell.warn("  Skipping #{pkg.app} (missing url/checksum)")
  defp get_artifact(pkg, nil, _, _), do: 
    Nerves.Utils.Shell.warn("  Skipping #{pkg.app} (missing url)")
  defp get_artifact(pkg, _, nil, _), do: 
    Nerves.Utils.Shell.warn("  Skipping #{pkg.app} (missing checksum)")
  defp get_artifact(pkg, _url, checksum, opts) do
    Nerves.Utils.Shell.success("  Resolving #{pkg.app}")
    toolchain = Nerves.Env.toolchain()
    case Resolver.get(pkg, toolchain, opts) do
      {:ok, archive} ->
        if checksum == Nerves.Package.Artifact.archive_checksum(archive) do
          destination = Artifact.dir(pkg, toolchain)
          unpack(archive, destination)
          Nerves.Utils.Shell.success("  => Success")
        else
          Nerves.Utils.Shell.error("  => Error: Checksums do not match")
          # TODO: Determine if we should toss the file if the checksums do not match
          #File.rm_rf(archive)
        end
      {:error, :nocache} ->
        Nerves.Utils.Shell.error("  => Failed to resolve after trying all locations")
    end
  end

  defp unpack(archive, destination) do
    Nerves.Utils.Shell.info("  => Unpacking #{destination}")
    File.mkdir_p!(destination)
    {_, status} = System.cmd("tar", ["xf", archive, "--strip-components=1", "-C", destination])
    case status do
      0 -> {:ok, destination}
      _ -> :error
    end
  end
end
