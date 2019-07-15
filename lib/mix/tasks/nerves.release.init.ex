defmodule Mix.Tasks.Nerves.Release.Init do
  use Mix.Task

  alias Nerves.Utils.Shell
  import Mix.Nerves.Utils

  @shortdoc "Prepare a new project for use with releases"

  @moduledoc """
  Prepares a new project for use with releases.
  By default, this forwards the call to

      mix release.init --template /path/to/nerves/release_template.eex

  For more information on additional args, see `mix help release.init`
  """

  @impl true
  def run(args) do
    if use_distillery?() do
      template_path = Path.join(["#{:code.priv_dir(:nerves)}", "templates", "release.eex"])
      Mix.Task.run("distillery.release.init", args ++ ["--template", template_path])
    else
      Shell.warn("mix nerves.release.init is not needed for Elixir 1.9+ projects")
    end
  end
end
