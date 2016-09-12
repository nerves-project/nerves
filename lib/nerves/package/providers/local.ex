defmodule Nerves.Package.Providers.Local do
  @behaviour Nerves.Package.Provider

  alias Nerves.Package.Artifact
  import Mix.Nerves.Utils

  def artifact(pkg, toolchain, opts) do
    {_, type} = :os.type
    artifact(type, pkg, toolchain, opts)
  end

  def artifact(:linux, pkg, toolchain, _opts) do
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

    shell "make", [], [cd: dest, stream: stream]
  end

  def artifact(type , _pkg, _toolchain, _opts) do
    {:error, """
    Local provider is not available for host system: #{type}
    Please use the Docker provider to build this package artifact
    """}
  end
end
