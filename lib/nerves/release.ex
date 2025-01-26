# credo:disable-for-this-file
defmodule Nerves.Release do
  @moduledoc false

  alias Nerves.Release.BootScript
  alias Nerves.Release.Options
  alias Nerves.Release.RootfsPriorities
  alias Nerves.Release.VmArgs

  # Legacy hook
  @doc false
  @spec init(Mix.Release.t()) :: Mix.Release.t()
  def init(%Mix.Release{} = release) do
    release
    |> Options.add_nerves_defaults()
    |> Map.put(:steps, release.steps ++ [&finalize/1])
    |> VmArgs.check_compatibility!()
    |> clean!()
    |> run_legacy_shoehorn_hook()
  end

  defp clean!(release) do
    _ = File.rm_rf!(release.path)
    release
  end

  defp run_legacy_shoehorn_hook(release) do
    if Code.ensure_loaded?(Shoehorn.Release) do
      apply(Shoehorn.Release, :init, [release])
    else
      release
    end
  end

  # Used by legacy init hook
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

  # This is in the new project generator, but why?
  @doc false
  @spec erts() :: String.t() | true | nil
  def erts() do
    if Nerves.Env.loaded?() do
      # TODO: It's an error if this is nil, right?
      System.get_env("ERTS_DIR")
    else
      true
    end
  end

  #### New release hooks ####
  def new_init(release) do
    release
    |> Options.add_nerves_defaults()
    |> VmArgs.check_compatibility!()
    |> BootScript.init()
    |> clean!()
  end

  def create_rootfs(release) do
    release
  end

  def create_firmware(release) do
    release
  end
end
