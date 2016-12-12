defmodule Mix.Tasks.Nerves.Release.Init do
  use Mix.Task

  @moduledoc """
  Prepares a new project for use with releases.
  By default, this forwards the call to
    mix release.init --template /path/to/nerves/release_template.eex

  For more information on additional args, reference
    mix help release.init
  """

  @spec run(OptionParser.argv) :: no_return
  def run(args) do
    template_path = Path.join(["#{:code.priv_dir(:nerves)}", "templates", "release.eex"])
    Mix.Task.run("release.init", args ++ ["--template", template_path])
  end
end
