defmodule NervesToolchainAarch64NervesLinuxGnu do
  @moduledoc false
  use Nerves.Package.Platform

  @impl Nerves.Package.Platform
  def bootstrap(_pkg) do
    :ok
  end

  @impl Nerves.Package.Platform
  def build_path_link(_pkg) do
    # Unused since never built via Nerves tooling
    "Run build.sh directly"
  end

  @impl Nerves.Artifact.BuildRunner
  def build(_pkg, _toolchain, _opts) do
    {:error, "Run build.sh directly"}
  end

  @impl Nerves.Artifact.BuildRunner
  def archive(_pkg, _toolchain, _opts) do
    {:error, "Run build.sh directly"}
  end

  @impl Nerves.Artifact.BuildRunner
  def clean(_pkg) do
    {:error, "Run build.sh directly"}
  end
end
