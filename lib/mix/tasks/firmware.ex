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

    system_path = System.get_env("NERVES_SYSTEM") || raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    _toolchain_path = System.get_env("NERVES_TOOLCHAIN") || raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """

    Mix.Task.run "release", ["--verbosity=#{verbosity}", "--no-confirm-missing", "--implode"]

    rel2fw_path = Path.join(system_path, "scripts/rel2fw.sh")
    "bash #{rel2fw_path} rel/#{otp_app} _images/#{target}/#{otp_app}.fw"
    |> shell
  end
end
