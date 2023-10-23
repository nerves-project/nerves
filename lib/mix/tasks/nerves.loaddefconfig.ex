defmodule Mix.Tasks.Nerves.Loaddefconfig do
  @shortdoc "Load nerves_defconfig into the Nerves artifact"

  @moduledoc """
  Load the nerves_defconfig configuration into the Nerves artifact.
  This is the opposite of `make savedefconfig`.

  ## Usage

      mix nerves.loaddefconfig

  """
  use Mix.Task
  import Mix.Nerves.IO

  @impl Mix.Task
  def run(_argv) do
    debug_info("loaddefconfig Start")
    Nerves.Env.disable()

    pkg_name = Mix.Project.config()[:app]
    pkg = Nerves.Env.package(pkg_name)
    script = Path.join(Nerves.Env.package(:nerves_system_br).path, "create-build.sh")
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join(pkg.path, platform_config)
    dest = Nerves.Artifact.build_path(pkg)

    Mix.Tasks.Nerves.Env.run(["#{script} #{defconfig} #{dest} >/dev/null"])

    Nerves.Env.enable()
    debug_info("loaddefconfig End")
  end
end
