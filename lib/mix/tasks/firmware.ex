defmodule Mix.Tasks.Firmware do
  use Mix.Task

  def run(args) do
    Mix.shell.info "Nerves Firmware Assembler"
    system = System.get_env("NERVES_SYSTEM") || raise """
      Environment variable $NERVES_SYSTEM is not set
    """

    toolchain = System.get_env("NERVES_TOOLCHAIN") || raise """
      Environment variable $NERVES_TOOLCHAIN is not set
    """
  end
end
