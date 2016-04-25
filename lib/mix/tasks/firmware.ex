defmodule Mix.Tasks.Firmware do
  use Mix.Task
  import Mix.Nerves.Utils

  @switches [verbosity: :string]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args)

    Mix.shell.info "Nerves Firmware Assembler"
    config = Mix.Project.config
    otp_app = config[:app]
    target = config[:target]
    verbosity = opts[:verbosity] || "normal"

    firmware_config = Application.get_env(:nerves, :firmware)

    system_path = System.get_env("NERVES_SYSTEM") || raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    _toolchain_path = System.get_env("NERVES_TOOLCHAIN") || raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """

    Mix.Task.run "release", ["--verbosity=#{verbosity}", "--no-confirm-missing", "--implode"]

    rel2fw_path = Path.join(system_path, "scripts/rel2fw.sh")
    cmd = "bash #{rel2fw_path}"
    rootfs_additions =
      case firmware_config[:rootfs_additions] do
        nil -> ""
        rootfs_additions ->
          rfs = File.cwd!
          |> Path.join(rootfs_additions)
          "-a " <> rfs
      end
    fw = "-f _images/#{target}/#{otp_app}.fw"
    output = "rel/#{otp_app}"
    %{status: 0} =
      [cmd, rootfs_additions, fw, output]
      |> Enum.join(" ")
      |> shell
  end
end
