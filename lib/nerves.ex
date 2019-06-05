defmodule Nerves do
  def version, do: unquote(Mix.Project.config()[:version])
  def elixir_version, do: unquote(System.version())

  # If distillery is present, load the plugin code
  if Code.ensure_loaded?(Distillery.Releases.Plugin) do
    defdelegate before_assembly(release, opts), to: Nerves.Distillery
    defdelegate after_assembly(release, opts), to: Nerves.Distillery
    defdelegate before_package(release, opts), to: Nerves.Distillery
    defdelegate after_package(release, opts), to: Nerves.Distillery
    defdelegate after_cleanup(release, opts), to: Nerves.Distillery
  end
end
