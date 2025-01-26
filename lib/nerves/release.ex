# credo:disable-for-this-file
defmodule Nerves.Release do
  @moduledoc false

  alias Nerves.Release.RootfsPriorities
  alias Nerves.Release.VmArgs

  @doc false
  @spec init(Mix.Release.t()) :: Mix.Release.t()
  def init(%{options: options} = release) do
    opts = Keyword.merge(options, release_opts())

    release = %{
      release
      | options: opts,
        steps: release.steps ++ [&Nerves.Release.finalize/1]
    }

    VmArgs.check_compatibility!(release)

    _ = File.rm_rf!(release.path)

    if Code.ensure_loaded?(Shoehorn.Release) do
      apply(Shoehorn.Release, :init, [release])
    else
      release
    end
  end

  @doc false
  @spec finalize(Mix.Release.t()) :: Mix.Release.t()
  def finalize(%Mix.Release{} = release) do
    bootfile_path = Path.join([release.version_path, bootfile()])

    case File.read(bootfile_path) do
      {:ok, bootfile} ->
        _ = RootfsPriorities.write_rootfs_priorities(release.applications, release.path, bootfile)
        :ok

      _ ->
        Nerves.Utils.Shell.warn("""
          Unable to load bootfile: #{inspect(bootfile_path)}
          Skipping rootfs priority file generation
        """)
    end

    release
  end

  defp bootfile() do
    Application.get_env(:nerves, :firmware)[:bootfile] || "shoehorn.boot"
  end

  @doc false
  @spec erts() :: String.t() | true | nil
  def erts() do
    if Nerves.Env.loaded?() do
      System.get_env("ERTS_DIR")
    else
      true
    end
  end

  defp release_opts() do
    [
      quiet: true,
      include_executables_for: [],
      include_erts: &Nerves.Release.erts/0,
      boot_scripts: []
    ]
  end
end
