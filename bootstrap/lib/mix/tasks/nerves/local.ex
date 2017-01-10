defmodule Mix.Tasks.Local.Nerves do
  use Mix.Task

  @url "https://github.com/nerves-project/archives/raw/master/nerves_bootstrap.ez"
  @shortdoc "Updates Nerves locally"

  @moduledoc """
  Updates Nerves locally.

      mix local.nerves

  Accepts the same command line options as `archive.install`.
  """
  def run(args) do
    Mix.Task.run "archive.install", [@url|args]
  end
end
