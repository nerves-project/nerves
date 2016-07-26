defmodule Mix.Tasks.Firmware do
  use Mix.Task
  import Mix.Nerves.Utils

  @switches [verbosity: :string]

  def run(args) do
    preflight

    {opts, _, _} = OptionParser.parse(args)
    debug_info "Nerves Firmware Assembler"
    config = Mix.Project.config
    otp_app = config[:app]
    target = config[:target]
    verbosity = opts[:verbosity] || "normal"

    firmware_config = Application.get_env(:nerves, :firmware)

    system_path = System.get_env("NERVES_SYSTEM") || raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    System.get_env("NERVES_TOOLCHAIN") || raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """
    Mix.Task.run "compile", [] # Maybe this should be in there?
    Mix.Task.run "release", ["--verbosity=#{verbosity}", "--no-confirm-missing", "--implode"]

    rel2fw_path = Path.join(system_path, "scripts/rel2fw.sh")
    cmd = "bash"
    args = [rel2fw_path]
    rootfs_additions =
      case firmware_config[:rootfs_additions] do
        nil -> []
        rootfs_additions ->
          rfs = File.cwd!
          |> Path.join(rootfs_additions)
          ["-a", rfs]
      end
    fwup_conf =
      case firmware_config[:fwup_conf] do
        nil -> []
        fwup_conf ->
          fw_conf = File.cwd!
          |> Path.join(fwup_conf)
          ["-c", fw_conf]
      end
    fw = ["-f", "_images/#{target}/#{otp_app}.fw"]
    output = ["rel/#{otp_app}"]
    args = args ++ fwup_conf ++ rootfs_additions ++ fw ++ output

    shell(cmd, args)
    |> result
  end

  def result({_ , 0}), do: nil
  def result({result, _}), do: Mix.raise """
  Nerves encountered an error. #{inspect result}
  """

  defp rel2fw(system) do
    # firmware_config = Application.get_env(:nerves, :firmware)
    # images_path = Mix.Project.config[:fw_images] || @default_images_path
    #
    # fw = Path.join(images_path, "#{otp_app}.fw")
    # rel = "rel/#{otp_app}"
    #
    # app_rootfs_additions = firmware_config[:rootfs_additions]
    # fwup_conf = firmware_config[:fwup_conf] || Path.join(system, "images/fwup.conf")
    #
    # fw
    # |> Path.dirname
    # |> File.mkdir_p!
    #
    # pkgs = Enum.map(Env.system_pkgs, & &1.app)
    # assemble_rootfs(system, pkgs)

  end

  defp assemble_rootfs(system, pkgs) do
    toolchain = Env.toolchain
    Application.ensure_started(toolchain[:app])
    target_tuple = Application.get_env(toolchain[:app], :target_tuple)

    pkg_dir = System.get_env("NERVES_SYSTEM_PKG_DIR") || Path.join(system, "pkgs")
    pkg_fs =
      pkgs
      |> Enum.reduce([], fn(pkgs) ->
        nil
      end)
  end

  def assemble_pkgs(pkgs, target_tuple) do
    # System.get_env("NERVES_SYSTEM_PKG_DIR")
    # |> fetch_pkg_assets(pkgs, target_tuple)
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
