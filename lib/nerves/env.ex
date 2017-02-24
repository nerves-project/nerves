defmodule Nerves.Env do
  @moduledoc """
  Contains package info for Nerves dependencies

  The Nerves Env is used to load information from dependencies that
  contain a nerves.exs config file in the root of the dependency
  path. Nerves loads this config because it needs access to information
  about Nerves compile time dependencies before any code is compiled.
  """

  alias Nerves.Package

  @doc """
  Starts the Nerves environment agent and loads package information.
  If the Nerves.Env is already started, the function returns
  `{:error, {:already_started, pid}}` with the pid of that process
  """
  @spec start() :: Agent.on_start
  def start do
    Agent.start_link(fn -> load_packages() end, name: __MODULE__)
  end

  @doc """
  Stop the Nerves environment agent.
  """
  @spec stop() :: :ok
  def stop do
    Agent.stop(__MODULE__)
  end

  @doc """
  Check if the env compilers are disabled
  """
  @spec enabled?() :: boolean
  def enabled?() do
    System.get_env("NERVES_ENV_DISABLED") == nil
  end

  @doc """
  Enable the Nerves Env compilers
  """
  @spec enable() :: :ok
  def enable() do
    System.delete_env("NERVES_ENV_DISABLED")
  end

  @doc """
  Disable the Nerves Env compilers
  """
  @spec disable() :: :ok
  def disable() do
    System.put_env("NERVES_ENV_DISABLED", "1")
  end

  @doc """
  Re evaluates the mix file under a different target.

  This allows you to start in one target, like host, but then
  switch to a different target.
  """
  @spec change_target(String.t) :: :no_return
  def change_target(target) do
    unless System.get_env("NERVES_TARGET_CHANGE") do
      System.put_env("MIX_TARGET", target)
      System.put_env("NERVES_TARGET_CHANGE", "1")
      :init.restart
      :timer.sleep(:infinity)
    end
  end

  @doc """
  Ensures that an application which contins a Nerves package config has
  been loaded into the environment agent.

  ## Options
    * `app` - The atom of the app to load
    * `path` - Optional path for the app
  """
  @spec ensure_loaded(app :: atom, path :: String.t) ::
    {:ok, Nerves.Package.t} | {:error, term}
  def ensure_loaded(app, path \\ nil) do
    path = path || File.cwd!
    packages = Agent.get(__MODULE__, &(&1))
    case Enum.find(packages, & &1.app == app) do
      nil ->
        case Package.load_config({app, path}) do
          %Package{} = package ->
            Agent.update(__MODULE__, fn(packages) ->
              [package | packages]
            end)
            {:ok, package}
          error ->
            error
        end
      package -> {:ok, package}
    end
  end

  @doc """
  Returns the archetecture for the host system.

  ## Example return values
    "x86_64"
    "arm"
  """
  @spec host_arch() :: String.t
  def host_arch() do
    :erlang.system_info(:system_architecture)
    |> to_string
    |> parse_arch
  end

  @doc false
  def parse_arch(arch) when is_binary(arch) do
    arch
    |> String.split("-")
    |> parse_arch
  end
  @doc false
  def parse_arch(arch) when is_list(arch) do
    arch = List.first(arch)
    case arch do
      <<"win", _tail :: binary>> -> "x86_64"
      arch ->
        if String.contains?(arch, "arm") do
          "arm"
        else
          "x86_64"
        end
    end
  end

  @doc """
  Returns the platform for the host system.

  ## Example return values
    "win"
    "linux"
    "darwin"
  """
  @spec host_platform() :: String.t
  def host_platform() do
    :erlang.system_info(:system_architecture)
    |> to_string
    |> parse_platform
  end
  @doc false
  def parse_platform(platform) when is_binary(platform) do
    platform
    |> String.split("-")
    |> parse_platform
  end
  @doc false
  def parse_platform(platform) when is_list(platform) do
    case platform do
      [<<"win", _tail :: binary>> | _] ->
        "win"
      [_ , _, "linux" | _] ->
        "linux"
      [_, _, <<"darwin", _tail :: binary>> | _] ->
        "darwin"
      _ ->
        Mix.raise "Could not determine your host platform from system: #{platform}"
    end
  end

  @doc """
  Lists all Nerves packages loaded in the Nerves environment.
  """
  @spec packages() :: [Nerves.Package.t]
  def packages do
    Agent.get(__MODULE__, &(&1)) || Mix.raise "Nerves packages are not loaded"
  end

  @doc """
  Gets a package by app name.
  """
  @spec package(name :: atom) ::
    Nerves.Package.t | nil
  def package(name) do
      packages()
      |> Enum.filter(& &1.app == name)
      |> List.first
  end

  @doc """
  Lists packages by package type.
  """
  @spec packages_by_type(type :: String.t) ::
    [Nerves.Package.t]
  def packages_by_type(type, packages \\ nil) do
    (packages || packages())
    |> Enum.filter(& &1.type === type)
  end

  @doc """
  Helper function for returning the system type package
  """
  @spec system() ::
    Nerves.Package.t
  def system do
    system =
      packages_by_type(:system)
      |> List.first
    system
  end

  @doc """
  Helper function for returning the system_platform type package
  """
  @spec system_platform() ::
    Nerves.Package.t
  def system_platform do
    system().platform
  end

  @doc """
  Helper function for returning the toolchain type package
  """
  @spec toolchain() ::
    Nerves.Package.t
  def toolchain do
    toolchain =
      packages_by_type(:toolchain)
      |> List.first
    toolchain
  end

  @doc """
  Helper function for returning the toolchain_platform type package
  """
  @spec toolchain_platform() ::
    Nerves.Package.t
  def toolchain_platform do
    toolchain().platform
  end

  @doc """
  Export environment variables used by Elixir, Erlang, C/C++ and other tools
  so that they use Nerves toolchain parameters and not the host's.

  For a comprehensive list of environment variables, see the documentation
  for the package defining system_platform.
  """
  @spec bootstrap() :: :ok
  def bootstrap do

    nerves_system_path = system_path()
    nerves_toolchain_path = toolchain_path()

    [{"NERVES_SYSTEM", nerves_system_path},
     {"NERVES_TOOLCHAIN", nerves_toolchain_path},
     {"NERVES_APP", File.cwd!}]
    |> Enum.each(fn({k, v}) ->
      cond do
        v == nil -> Mix.shell.info "#{k} is unset"
        File.dir?(v) != true ->
          Mix.shell.info """
          #{k} is set to a path which does not exist:
          #{v}
          """
          System.put_env(k, v)
        true -> System.put_env(k, v)
      end
    end)

    if nerves_system_path != nil and File.dir?(nerves_system_path) do
      # Bootstrap the build platform
      platform = Nerves.Env.system.platform
      # Pre 0.4.0 Legacy
      platform = platform || Nerves.Env.system.config[:build_platform]
      ## end re 0.4.0 Legacy
      pkg =
        Nerves.Env.packages_by_type(:system_platform)
        |> List.first
      platform.bootstrap(pkg)
    end
  end

  @doc false
  defp load_packages do
    Mix.Project.deps_paths
    |> Enum.filter(fn({_, path}) ->
      Package.config_path(path)
      |> File.exists?
    end)
    |> Enum.map(&Package.load_config/1)
    |> validate_packages
  end

  @doc false
  defp validate_packages(packages) do
    for type <- [:system, :toolchain] do
      packages_by_type(type, packages)
      |> validate_one(type)
    end
    packages
  end

  @doc false
  defp validate_one(packages, type) when length(packages) > 1 do
    packages = Enum.map(packages, &(Map.get(&1, :app)))
    Mix.raise """
    Your mix project cannot contain more than one #{type} for the target.
    Your dependancies for the target contian the following #{type}s:
    #{Enum.join(packages, ~s/ /)}
    """
  end
  @doc false
  defp validate_one(packages, _type), do: packages

  @doc false
  defp toolchain_path do
    case Nerves.Env.toolchain do
      nil -> nil
      toolchain ->
        Nerves.Package.Artifact.dir(toolchain, toolchain)
    end
  end
  @doc false
  defp system_path do
    case Nerves.Env.system do
      nil -> nil
      system ->
        toolchain = Nerves.Env.toolchain
        Nerves.Package.Artifact.dir(system, toolchain)
    end
  end

  # Pre 0.4.0 Legacy
  @doc false
  def initialize, do: start()
  @doc false
  def stale? do
    system_manifest =
      system_path()
      |> Path.join(".nerves.lock")
      |> Path.expand

    if stale_check_manifest(system_manifest) do
      false
    else
      true
    end
  end
  @doc false
  def stale_check_manifest(manifest) do
    case File.read(manifest) do
      {:ok, file} ->
        file
        |> :erlang.binary_to_term
        |> Keyword.equal?(packages())
      _ -> false
    end
  end
  @doc false
  def deps, do: packages()
  @doc false
  def deps_by_type(type), do: packages_by_type(type)
  ## End Pre 0.4.0 Legacy

end
