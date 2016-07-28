defmodule Nerves.Package do
  defstruct [app: nil, path: nil, dep: nil, type: nil, version: nil, platform: nil, config: []]

  alias __MODULE__
  alias Nerves.Package.Artifact

  @type t :: %__MODULE__{app: atom,
                        path: binary,
                        type: :system |
                              :package |
                              :toolchain,
                         dep: :project |
                              :path |
                              :hex |
                              :git,
                    platform: atom,
                     version: Version.t,
                      config: Keyword.t}

  @package_config "nerves.exs"
  @artifacts_dir Path.expand("~/.nerves/artifacts")
  @required [:type, :version, :platform]

  def load_config({app, path}) do
    load_nerves_config(path)
    config = Application.get_env(app, :nerves_env)
    version = config[:version] || Mix.raise "The Nerves package #{app} does not define its version"
    type = config[:type] || Mix.raise "The Nerves package #{app} does not define a type"
    platform = config[:platform]
    config = Enum.reject(config, fn({k, _v}) -> k in @required end)
    %Package{
      app: app,
      type: type,
      platform: platform,
      dep: dep_type(app),
      path: path,
      version: version,
      config: config}
  end

  def config_path(path) do
    Path.join(path, @package_config)
  end

  def stale?(pkg, toolchain) do
    !Artifact.exists?(pkg, toolchain)
  end

  defp load_nerves_config(path) do
    config_path(path)
    |> Mix.Config.read!
    |> Mix.Config.persist
  end

  defp dep_type(pkg) do
    deps_paths = Mix.Project.deps_paths
    case Map.get(deps_paths, pkg) do
      nil ->
        :project
      path ->
        deps_path =
          File.cwd!
          |> Path.join(Mix.Project.config[:deps_path])

        if String.starts_with?(path, deps_path) do
          :hex
        else
          :path
        end
    end
  end

end
