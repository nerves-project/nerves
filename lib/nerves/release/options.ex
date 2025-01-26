defmodule Nerves.Release.Options do
  @moduledoc false

  @doc false
  @spec add_nerves_defaults(Mix.Release.t()) :: Mix.Release.t()
  def add_nerves_defaults(release) do
    options = Keyword.merge(release.options, defaults())

    %{release | options: options}
  end

  defp defaults() do
    [
      # quiet: true,
      include_executables_for: [],
      include_erts: &Nerves.Release.erts/0,
      boot_scripts: []
    ]
  end
end
