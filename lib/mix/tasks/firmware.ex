defmodule Mix.Tasks.Firmware do
  use Mix.Task
  import Mix.Nerves.Utils

  @switches [verbosity: :string]

  @default_images_path "_images/#{Mix.Project.config[:target]}"

  def run(args) do
    preflight

    {opts, _, _} = OptionParser.parse(args)
    Mix.shell.info "Nerves Firmware Assembler"
    config = Mix.Project.config
    otp_app = config[:app]
    target = config[:target]
    verbosity = opts[:verbosity] || "normal"

    system_path = System.get_env("NERVES_SYSTEM") || raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    System.get_env("NERVES_TOOLCHAIN") || raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """
    Mix.Task.run "compile", [] # Maybe this should be in there?
    Mix.Task.run "release", ["--verbosity=#{verbosity}", "--no-confirm-missing", "--implode"]

    rel2fw(system_path)
  end

  def result(%{status: 0}), do: nil
  def result(result), do: Mix.raise """
  Nerves encountered an error. #{inspect result}
  """

  defp rel2fw(system) do
    firmware_config = Application.get_env(:nerves, :firmware)
    images_path = Mix.Project.config[:fw_images] || @default_images_path

    fw = Path.join(images_path, "#{otp_app}.fw")
    rel = "rel/#{otp_app}"

    app_rootfs_additions = firmware_config[:rootfs_additions]
    fwup_conf = firmware_config[:fwup_conf] || Path.join(system, "images/fwup.conf")

    fw
    |> Path.dirname
    |> File.mkdir_p!

    pkgs = Enum.map(Env.system_pkgs, & &1.app)
    assemble_rootfs(system, pkgs)

  end

  defp assemble_rootfs(system, pkgs) do
    toolchain = Env.toolchain
    Application.ensure_started(toolchain[:app])
    target_tuple = Application.get_env(toolchain[:app], :target_tuple)

    pkg_dir = System.get_env("NERVES_SYSTEM_PKG_DIR") || Path.join(system, "pkgs")
    pkg_fs =
      pkgs
      |> Enum.reduce([], fn(pkgs) ->
        
      end)
  end

  def assemble_pkgs(pkgs, target_tuple) do
    System.get_env("NERVES_SYSTEM_PKG_DIR")
    |> fetch_pkg_assets(pkgs, target_tuple)
  end

  # Fetch the assets from the network
  defp fetch_pkg_assets(nil, _pkgs) do

  end

  # Fetch the assets from a local directory
  defp fetch_pkg_assets(path, pkgs) do
    pkgs
    |> Enum.reduce(fn (%{app: app}) ->
      fs_overlay =
        path
        |> Path.join("#{name}-")
    end)
  end
end
