defmodule Nerves.Package.Artifact.Providers.Local do
  @moduledoc """
  Builds an artifact locally.

  This provider will only function on certain Linux host configurations
  """

  @behaviour Nerves.Package.Artifact.Provider

  alias Nerves.Package.Artifact
  import Mix.Nerves.Utils

  @doc """
  Builds an artifact locally.
  """
  @spec build(Nerves.Package.t, Nerves.Package.t, term) :: :ok
  def build(pkg, toolchain, opts) do
    {_, type} = :os.type
    make(type, pkg, toolchain, opts)
  end

  def clean(pkg) do
    dest = Artifact.dir(pkg, Nerves.Env.toolchain)
    File.rm_rf(dest)
    File.mkdir_p!(dest)
  end

  @doc """
  Connect to a system configuration sub-shell
  """
  @spec system_shell(Nerves.Package.t) :: :ok
  def system_shell(pkg) do
    dest = Artifact.dir(pkg, Nerves.Env.toolchain)

    shell = System.get_env("SHELL") || "/bin/bash"

    script = Path.join(Nerves.Env.package(:nerves_system_br).path, "create-build.sh")
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("#{pkg.path}", platform_config)

    initial_input = [
      "echo Updating build directory.",
      "echo This will take a while if it is the first time...",
      "#{script} #{defconfig} #{dest} >/dev/null",
      "cd #{dest}",
    ]

    Mix.Nerves.Shell.open(shell, initial_input)
  end

  defp make(:linux, pkg, toolchain, _opts) do
    System.delete_env("BINDIR")
    dest = Artifact.dir(pkg, toolchain)

    script = Path.join(Nerves.Env.package(:nerves_system_br).path, "create-build.sh")
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("#{pkg.path}", platform_config)
    shell(script, [defconfig, dest])

    {:ok, pid} = Nerves.Utils.Stream.start_link(file: "build.log")
    stream = IO.stream(pid, :line)

    case shell("make", [], [cd: dest, stream: stream]) do
      {_, 0} -> {:ok, dest}
      {_error, _} -> {:error, Nerves.Utils.Stream.history(pid)}
    end
  end

  defp make(type , _pkg, _toolchain, _opts) do
    {:error, """
    Local provider is not available for host system: #{type}
    Please use the Docker provider to build this package artifact
    """}
  end

end
