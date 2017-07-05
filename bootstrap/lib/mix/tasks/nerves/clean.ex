defmodule Mix.Tasks.Nerves.Clean do
  use Mix.Task
  import Mix.Nerves.IO

  @shortdoc "Clean artifacts for a Nerves package"

  @moduledoc """
  Cleans the build artifacts and fetches sources for given dependencies

  Since this is a destructive action, cleaning of dependencies
  only occurs when one of the following are specified:
    * `dep1 dep2` - the names of Nerves dependencies to be cleaned, separated by spaces
    * `--all` - cleans all Nerves dependencies
  """

  @switches [all: :boolean]

  def run(argv) do
    debug_info "Clean Start"
    {opts, packages, _} = OptionParser.parse(argv, switches: @switches)
    Mix.Tasks.Nerves.Env.run([])

    packages =
      case packages do
        [] ->
          if opts[:all] do
            Nerves.Env.packages
          else
            Mix.raise """
            You must specify the Nerves dependencies to clean, seperated by spaces
            Example:
              mix nerves.clean nerves_system_rpi3
            Or by passing --all
              mix nerves.clean --all
            """
          end
        packages ->
          packages
          |> Enum.map(&String.to_existing_atom/1)
          |> Enum.map(&Nerves.Env.package/1)
      end
      debug_info "Clean End"
    Nerves.Env.clean(packages)
  end

end
