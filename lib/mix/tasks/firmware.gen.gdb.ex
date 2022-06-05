defmodule Mix.Tasks.Firmware.Gen.Gdb do
  @shortdoc "Generates a helper shell script for using gdb to analyze core dumps"
  @moduledoc """
  Generates a helper shell script for using gdb to analyze core dumps

  This script may be used on its own or used as a base for more complicated debugging.
  It saves the script to gdb.sh.
  """
  use Mix.Task
  import Mix.Nerves.Utils
  alias Mix.Nerves.Preflight
  @script_name "gdb.sh"

  @impl Mix.Task
  def run(_args) do
    Preflight.check!()
    system_path = check_nerves_system_is_set!()
    _ = check_nerves_toolchain_is_set!()

    gdb_script_contents =
      Application.app_dir(:nerves, "priv/templates/script.run-gdb.sh.eex")
      |> EEx.eval_file(assigns: [nerves_system: system_path])

    if File.exists?(@script_name) do
      Mix.shell().yes?("OK to overwrite #{@script_name}?") || Mix.raise("Aborted")
    end

    Mix.shell().info("""
    Writing #{@script_name}...
    """)

    File.write!(@script_name, gdb_script_contents)
    File.chmod!(@script_name, 0o755)
  end
end
