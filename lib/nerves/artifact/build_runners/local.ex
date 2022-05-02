defmodule Nerves.Artifact.BuildRunners.Local do
  @moduledoc """
  Builds an artifact locally.

  This build_runner will only function on certain Linux host configurations
  """
  @behaviour Nerves.Artifact.BuildRunner

  alias Nerves.Artifact

  @doc """
  Builds an artifact locally.

  Opts:
    `make_args:` - Extra arguments to be passed to make.

    For example:

    You can configure the number of parallel jobs that buildroot
    can use for execution. This is useful for situations where you may
    have a machine with a lot of CPUs but not enough ram.

      # mix.exs
      defp nerves_package do
        [
          # ...
          build_runner_opts: [make_args: ["PARALLEL_JOBS=8"]],
        ]
      end
  """
  @impl Nerves.Artifact.BuildRunner
  def build(pkg, toolchain, opts) do
    pkg.platform.build(pkg, toolchain, opts)
  end

  @doc """
  Builds an artifact locally.
  """
  @impl Nerves.Artifact.BuildRunner
  def archive(pkg, toolchain, opts) do
    pkg.platform.archive(pkg, toolchain, opts)
  end

  @doc """
  Builds an artifact locally.
  """
  @impl Nerves.Artifact.BuildRunner
  def clean(pkg) do
    pkg.platform.clean(pkg)
  end

  @doc """
  Connect to a system configuration sub-shell
  """
  @spec system_shell(Nerves.Package.t()) :: :ok
  def system_shell(pkg) do
    dest = Artifact.build_path(pkg)

    error = """
    Could not find bash or sh executable.
    Make sure one of them are in your $PATH environment variable
    """

    shell = System.find_executable("bash") || System.find_executable("sh") || Mix.raise(error)

    script = Path.join(Nerves.Env.package(:nerves_system_br).path, "create-build.sh")
    platform_config = pkg.config[:platform_config][:defconfig]
    defconfig = Path.join("#{pkg.path}", platform_config)

    initial_input = [
      "echo Updating build directory.",
      "echo This will take a while if it is the first time...",
      "#{script} #{defconfig} #{dest} >/dev/null",
      "cd #{dest}"
    ]

    Mix.Nerves.Shell.open(shell, initial_input)
  end
end
