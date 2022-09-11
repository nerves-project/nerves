defmodule Nerves.Env do
  @moduledoc """
  Contains package info for Nerves dependencies

  The Nerves Env is used to load information from dependencies that
  contain a nerves.exs config file in the root of the dependency
  path. Nerves loads this config because it needs access to information
  about Nerves compile time dependencies before any code is compiled.
  """

  alias Nerves.{Artifact, Package}

  @doc """
  Starts the Nerves environment agent and loads package information.
  If the Nerves.Env is already started, the function returns
  `{:error, {:already_started, pid}}` with the pid of that process
  """
  @spec start() :: Agent.on_start()
  def start() do
    set_source_date_epoch()
    Agent.start_link(fn -> load_packages() end, name: __MODULE__)
  end

  @doc """
  Stop the Nerves environment agent.
  """
  @spec stop() :: :ok | :not_running
  def stop() do
    if Process.whereis(__MODULE__) do
      Agent.stop(__MODULE__)
    else
      :not_running
    end
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
  Check if the Nerves.Env is loaded
  """
  @spec loaded?() :: boolean
  def loaded?() do
    System.get_env("NERVES_ENV_BOOTSTRAP") != nil
  end

  @doc """
  The download location for artifact downloads.

  Placing an artifact tar in this location will bypass the need for it to
  be downloaded.
  """
  @spec download_dir() :: path :: String.t()
  def download_dir() do
    (System.get_env("NERVES_DL_DIR") || Path.join(data_dir(), "dl"))
    |> Path.expand()
  end

  @doc """
  The location for storing global nerves data.

  The base directory is normally set by the `XDG_DATA_HOME`
  environment variable (i.e. `$XDG_DATA_HOME/nerves/`).
  If `XDG_DATA_HOME` is unset, the user's home directory
  is used (i.e. `$HOME/.nerves`).
  """
  @spec data_dir() :: path :: String.t()
  def data_dir() do
    case System.get_env("XDG_DATA_HOME") do
      directory when is_binary(directory) -> Path.join(directory, "nerves")
      nil -> Path.expand("~/.nerves")
    end
  end

  @doc """
  Re evaluates the mix file under a different target.

  This allows you to start in one target, like host, but then
  switch to a different target.
  """
  @spec change_target(String.t()) :: :ok
  def change_target(target) do
    System.put_env("MIX_TARGET", target)
    :init.restart()
    :timer.sleep(:infinity)
  end

  @doc """
  Cleans the artifacts for the package build_runners of all specified packages.
  """
  @spec clean([Nerves.Package.t()]) :: :ok
  def clean(pkgs) do
    Enum.each(pkgs, &Artifact.clean/1)
  end

  @doc """
  Ensures that an application which contains a Nerves package config has
  been loaded into the environment agent.

  ## Options
    * `app` - The atom of the app to load
    * `path` - Optional path for the app
  """
  @spec ensure_loaded(app :: atom, path :: String.t() | nil) ::
          {:ok, Nerves.Package.t()} | {:error, term}
  def ensure_loaded(app, path \\ nil) do
    path = path || File.cwd!()

    if nerves_package?({app, path}) do
      packages = Agent.get(__MODULE__, & &1)

      case Enum.find(packages, &(&1.app == app)) do
        nil ->
          %Package{} = package = Package.load_config({app, path})

          Agent.update(__MODULE__, fn packages ->
            [package | packages]
          end)

          {:ok, package}

        package ->
          {:ok, package}
      end
    else
      {:error, "Nerves package config for #{inspect(app)} was not found at #{path}"}
    end
  end

  @doc """
  Returns the architecture for the host system.

  ## Example return values
    "x86_64"
    "arm"
  """
  @spec host_arch() :: String.t()
  def host_arch() do
    case System.get_env("HOST_ARCH") do
      nil ->
        :erlang.system_info(:system_architecture)
        |> to_string
        |> parse_arch

      host_arch ->
        host_arch
    end
  end

  @doc false
  @spec parse_arch(String.t() | [String.t()]) :: String.t()
  def parse_arch(arch) when is_binary(arch) do
    arch
    |> String.split("-")
    |> parse_arch
  end

  @doc false
  def parse_arch(arch) when is_list(arch) do
    arch = List.first(arch)

    case arch do
      <<"win", _rest::binary>> -> "x86_64"
      <<"arm", _rest::binary>> -> "arm"
      "aarch64" -> "aarch64"
      "x86_64" -> "x86_64"
      _anything_else -> "x86_64"
    end
  end

  @doc """
  Returns the os for the host system.

  ## Example return values
    "win"
    "linux"
    "darwin"
  """
  @spec host_os() :: String.t()
  def host_os() do
    case System.get_env("HOST_OS") do
      nil ->
        :erlang.system_info(:system_architecture)
        |> to_string
        |> parse_platform

      host_os ->
        host_os
    end
  end

  @doc false
  @spec parse_platform(String.t() | [String.t()]) :: String.t()
  def parse_platform(platform) when is_binary(platform) do
    platform
    |> String.split("-")
    |> parse_platform
  end

  @doc false
  def parse_platform(platform) when is_list(platform) do
    case platform do
      [<<"win", _tail::binary>> | _] ->
        "win"

      [_, _, "linux" | _] ->
        "linux"

      [_, _, <<"darwin", _tail::binary>> | _] ->
        "darwin"

      _ ->
        Mix.raise("Could not determine your host platform from system: #{platform}")
    end
  end

  @doc """
  Lists all Nerves packages loaded in the Nerves environment.
  """
  @spec packages() :: [Nerves.Package.t()]
  def packages() do
    Agent.get(__MODULE__, & &1) || Mix.raise("Nerves packages are not loaded")
  end

  @doc """
  Gets a package by app name.
  """
  @spec package(name :: atom) :: Nerves.Package.t() | nil
  def package(name) do
    packages()
    |> Enum.filter(&(&1.app == name))
    |> List.first()
  end

  @doc """
  Lists packages by package type.
  """
  @spec packages_by_type(type :: atom(), [Nerves.Package.t()] | nil) :: [Nerves.Package.t()]
  def packages_by_type(type, packages \\ nil) do
    (packages || packages())
    |> Enum.filter(&(&1.type === type))
  end

  @doc """
  The path to where firmware build files are stored
  This can be overridden in a Mix project by setting the `:images_path` key.

    images_path: "/some/other/location"

  Defaults to (build_path)/nerves/images
  """
  @spec images_path(keyword) :: String.t()
  def images_path(config \\ mix_config()) do
    (config[:images_path] || Path.join([Mix.Project.build_path(), "nerves", "images"]))
    |> Path.expand()
  end

  @doc """
  The path to the firmware file
  """
  @spec firmware_path(keyword) :: String.t()
  def firmware_path(config \\ mix_config()) do
    config
    |> images_path()
    |> Path.join("#{config[:app]}.fw")
  end

  @doc """
  Helper function for returning the system type package
  """
  @spec system() :: Nerves.Package.t() | nil
  def system() do
    system =
      packages_by_type(:system)
      |> List.first()

    system
  end

  @doc """
  Helper function for returning the system_platform type package
  """
  @spec system_platform() :: module()
  def system_platform() do
    system().platform
  end

  @doc """
  Helper function for returning the toolchain type package
  """
  @spec toolchain() :: Nerves.Package.t() | nil
  def toolchain() do
    toolchain =
      packages_by_type(:toolchain)
      |> List.first()

    toolchain
  end

  @doc """
  Helper function for returning the toolchain_platform type package
  """
  @spec toolchain_platform() :: atom()
  def toolchain_platform() do
    toolchain().platform
  end

  @doc """
  Export environment variables used by Elixir, Erlang, C/C++ and other tools
  so that they use Nerves toolchain parameters and not the host's.

  For a comprehensive list of environment variables, see the documentation
  for the package defining system_platform.
  """
  @spec bootstrap() :: :ok
  def bootstrap() do
    nerves_system_path = system_path()
    nerves_toolchain_path = toolchain_path()
    packages = Nerves.Env.packages()

    [
      {"NERVES_SYSTEM", nerves_system_path},
      {"NERVES_TOOLCHAIN", nerves_toolchain_path},
      {"NERVES_APP", File.cwd!()}
    ]
    |> Enum.each(fn {k, v} ->
      cond do
        v == nil ->
          Mix.shell().info("#{k} is unset")

        File.dir?(v) != true ->
          with "NERVES_SYSTEM" <- k,
               %{app: app, dep: :path} <- system() do
            Mix.shell().info([
              :yellow,
              """
              Local Nerves system detected but is not compiled:

                #{app}
              """,
              :reset
            ])

            # Since this is a local system, let this be set
            # so that the compilation check later on can handle if
            # it should be compiled or not
            System.put_env(k, v)
          else
            _err ->
              Mix.shell().error("""
              #{k} is set to a path which does not exist:
              #{v}

              Try running `mix deps.get` to see if this resolves the issue by
              downloading the missing artifact.
              """)

              exit({:shutdown, 1})
          end

        true ->
          System.put_env(k, v)
      end
    end)

    if nerves_system_path != nil and File.dir?(nerves_system_path) do
      # Bootstrap the build platform
      platform = Nerves.Env.system().platform

      pkg =
        Nerves.Env.packages_by_type(:system_platform)
        |> List.first()

      platform.bootstrap(pkg)
    end

    # Export nerves package env variables
    Enum.each(packages, &export_package_env/1)

    # Bootstrap all other packages who define a platform
    toolchain_package = Nerves.Env.toolchain()
    system_package = Nerves.Env.system()

    packages
    |> Enum.reject(&(&1 == toolchain_package or &1 == system_package or &1.platform == nil))
    |> Enum.each(fn
      %{platform: platform} = pkg ->
        platform.bootstrap(pkg)

      _ ->
        :noop
    end)

    System.put_env("NERVES_ENV_BOOTSTRAP", "1")
  end

  @doc false
  @spec toolchain_path() :: String.t() | nil
  def toolchain_path() do
    case Nerves.Env.toolchain() do
      nil ->
        nil

      toolchain ->
        Nerves.Artifact.dir(toolchain)
    end
  end

  @doc false
  @spec system_path() :: String.t() | nil
  def system_path() do
    case Nerves.Env.system() do
      nil ->
        nil

      system ->
        Nerves.Artifact.dir(system)
    end
  end

  @doc false
  @spec source_date_epoch() :: {:ok, String.t() | nil} | {:error, String.t()}
  def source_date_epoch() do
    (System.get_env("SOURCE_DATE_EPOCH") || Application.get_env(:nerves, :source_date_epoch))
    |> validate_source_date_epoch()
  end

  @spec export_package_env(Package.t()) :: :ok
  def export_package_env(%Package{env: env}) do
    env
    |> process_target_gcc_flags()
    |> System.put_env()
  end

  defp process_target_gcc_flags(%{"TARGET_GCC_FLAGS" => flags} = env) do
    env
    |> Map.put("CFLAGS", flags <> " " <> System.get_env("CFLAGS", ""))
    |> Map.put("CXXFLAGS", flags <> " " <> System.get_env("CXXFLAGS", ""))
  end

  defp process_target_gcc_flags(env), do: env

  defp set_source_date_epoch() do
    case source_date_epoch() do
      {:ok, nil} -> :ok
      {:ok, sde} -> System.put_env("SOURCE_DATE_EPOCH", sde)
      {:error, error} -> Mix.raise(error)
    end
  end

  defp validate_source_date_epoch(nil), do: {:ok, nil}
  defp validate_source_date_epoch(sde) when is_integer(sde), do: {:ok, Integer.to_string(sde)}
  defp validate_source_date_epoch(""), do: {:error, "SOURCE_DATE_EPOCH cannot be empty"}

  defp validate_source_date_epoch(sde) when is_binary(sde) do
    case Integer.parse(sde) do
      {_sde, _rem} ->
        {:ok, sde}

      :error ->
        {:error, "SOURCE_DATE_EPOCH should be a positive integer, received: #{inspect(sde)}"}
    end
  end

  @doc false
  defp load_packages() do
    Mix.Project.deps_paths()
    |> Map.put(Mix.Project.config()[:app], File.cwd!())
    |> Enum.filter(&nerves_package?/1)
    |> Enum.map(&Package.load_config/1)
    |> validate_packages
  end

  @doc false
  defp validate_packages(packages) do
    Enum.each([:system, :toolchain], fn type ->
      packages_by_type(type, packages)
      |> validate_one(type)
    end)

    packages
  end

  @doc false
  defp validate_one(packages, type) when length(packages) > 1 do
    packages = Enum.map(packages, &Map.get(&1, :app))

    Mix.raise("""
    Your mix project cannot contain more than one #{type} for the target.
    Your dependencies for the target contain the following #{type}s:
    #{Enum.join(packages, ~s/ /)}
    """)
  end

  @doc false
  defp validate_one(packages, _type), do: packages

  @doc false
  defp nerves_package?({app, path}) do
    package_config =
      Package.config(app, path)
      |> Keyword.get(:nerves_package)

    package_config != nil
  rescue
    _e ->
      File.exists?(Package.config_path(path))
  end

  defp mix_config() do
    Mix.Project.config()
  end
end
