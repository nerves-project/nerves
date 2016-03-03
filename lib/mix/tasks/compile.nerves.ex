defmodule Mix.Tasks.Compile.Nerves do
  use Mix.Task

  require Logger

  @moduledoc """

  """

  def run(args) do
    # Mix.shell.info "==> Compile Nerves"
    #
    # {:ok, _} = Application.ensure_all_started(:nerves)
    # config = Application.get_all_env(:nerves)
    # Mix.Task.run "compile.nerves_system", ["--system", config[:system]] ++ args
    # Logger.debug "Config: #{inspect config}"
    #
    # compile.nerves_toolchain
    # compile.nerves_system
  end
end
