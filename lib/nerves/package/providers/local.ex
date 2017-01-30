defmodule Nerves.Package.Providers.Local do
  @moduledoc """
  Builds an artifact locally.

  This provider will only function on certain Linux host configurations
  """

  @behaviour Nerves.Package.Provider

  alias Nerves.Package.Artifact
  import Mix.Nerves.Utils

  @doc """
  Builds an artifact locally.
  """
  @spec artifact(Nerves.Package.t, Nerves.Package.t, term) :: :ok
  def artifact(pkg, toolchain, opts) do
    {_, type} = :os.type
    build(type, pkg, toolchain, opts)
  end

  defp build(:linux, pkg, toolchain, _opts) do
    System.delete_env("BINDIR")
    dest = Artifact.dir(pkg, toolchain)
    File.rm_rf(dest)
    File.mkdir_p!(dest)

    script = Path.join(Nerves.Env.package(:nerves_system_br).path, "create-build.sh")
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("#{pkg.path}", platform_config)
    shell(script, [defconfig, dest])

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "build.log")
    stream = IO.stream(pid, :line)

    case shell("make", [], [cd: dest, stream: stream]) do
      {_, 0} -> :ok
      {error, _} -> {:error, error}
    end
  end

  defp build(type , _pkg, _toolchain, _opts) do
    {:error, """
    Local provider is not available for host system: #{type}
    Please use the Docker provider to build this package artifact
    """}
  end

  # def shell(_pkg, _opts) do
  #   :ok
  # end
  #
  # def clean(_pkg, _opts) do
  #   :ok
  # end
end
