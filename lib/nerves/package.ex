defmodule Nerves.Package do
  defstruct [app: nil, path: nil, dep: nil, type: nil, version: nil, platform: nil, provider: nil, config: []]

  alias __MODULE__
  alias Nerves.Package.{Artifact, Providers}

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
                    provider: atom,
                     version: Version.t,
                      config: Keyword.t}

  @package_config "nerves.exs"
  @artifacts_dir Path.expand("~/.nerves/artifacts")
  @required [:type, :version, :platform]

  def artifact(pkg, toolchain) do

    pkg.provider.artifact(pkg, toolchain)
  end

  def load_config({app, path}) do
    load_nerves_config(path)
    config = Application.get_env(app, :nerves_env)
    version = config[:version] || Mix.raise "The Nerves package #{app} does not define its version"
    type = config[:type] || Mix.raise "The Nerves package #{app} does not define a type"
    platform = config[:platform]
    provider = provider(app, type)
    config = Enum.reject(config, fn({k, _v}) -> k in @required end)

    %Package{
      app: app,
      type: type,
      platform: platform,
      provider: provider,
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

  def shell(nil) do
    Mix.raise "Package is not loaded in your Nerves Environment."
  end

  def shell(%{platform: nil, app: app}) do
    Mix.raise "Cannot start shell for #{app}"
  end

  def shell(pkg) do
    pkg.provider.shell(pkg)
  end

  defp provider(app, type) do
    config = Mix.Project.config[:artifacts] || []

    case Keyword.get(config, app) do
      nil -> {provider_mod(type), []}
      opts -> provider_opts(opts)
    end
  end

  defp provider_mod(:toolchain) do
    case :os.type do
      {_, :linux} -> Providers.Local
      {_, :darwin} -> Providers.Local
      _ -> Providers.Docker
    end
  end

  defp provider_mod(_) do
    case :os.type do
      {_, :linux} -> Providers.Local
      _ -> Providers.Docker
    end
  end

  defp provider_opts(mod) when is_atom(mod), do: {mod, []}
  defp provider_opts(opts) when is_list(opts) do
    mod =
      cond do
        opts[:path] != nil -> Providers.Path
        opts[:url] != nil -> Providers.HTTP
        true -> Mix.raise "Invalid artifact options"
      end
    {mod, opts}
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
