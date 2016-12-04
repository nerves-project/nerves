defmodule Nerves.Env do
  alias Nerves.Package

  # Pre 0.4.0 Legacy
  def initialize, do: start()
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

  def stale_check_manifest(manifest) do
    case File.read(manifest) do
      {:ok, file} ->
        file
        |> :erlang.binary_to_term
        |> Keyword.equal?(packages())
      _ -> false
    end
  end
  def deps, do: packages()
  def deps_by_type(type), do: packages_by_type(type)
  ## End Pre 0.4.0 Legacy

  def start do
    Agent.start_link fn -> load_packages() end, name: __MODULE__
  end

  def stop do
    Agent.stop(__MODULE__)
  end

  def ensure_loaded(app, path \\ nil) do
    path = path || File.cwd!

    Agent.update(__MODULE__, fn(packages) ->
      case Enum.find(packages, & &1.app == app) do
        nil ->
          package = Package.load_config({app, path})
          [package | packages]
        _ -> packages
      end
    end)
  end

  def host_arch() do
    :erlang.system_info(:system_architecture)
    |> to_string
    |> parse_arch
  end

  def parse_arch(arch) when is_binary(arch) do
    arch
    |> String.split("-")
    |> parse_arch
  end
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

  def host_platform() do
    :erlang.system_info(:system_architecture)
    |> to_string
    |> parse_platform
  end

  def parse_platform(platform) when is_binary(platform) do
    platform
    |> String.split("-")
    |> parse_platform
  end
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

  def packages do
    get() || raise "Nerves packages are not loaded"
  end

  def package(name) when is_binary(name) do
    name
    |> String.to_atom
    |> package
  end
  def package(name) do
    packages()
    |> Enum.filter(& &1.app == name)
    |> List.first
  end

  def packages_by_type(type) do
    packages()
    |> packages_by_type(type)
  end

  def packages_by_type(packages, type) do
    packages
    |> Enum.filter(& &1.type === type)
  end

  def system do
    system =
      packages_by_type(:system)
      |> List.first

    system || Mix.raise "Could not locate System"
  end

  def system_platform do
    system().config[:platform]
  end

  def system_pkg do
    packages_by_type(:system_pkg)
  end

  def toolchain do
    toolchain =
      packages_by_type(:toolchain)
      |> List.first
    toolchain || Mix.raise "Could not locate Toolchain"

  end

  # Collect all deps containing #{dep_path}/nerves.exs
  # Each Nerves Dep
  #  * Load the nerves.exs
  #  * Determine the project type
  #    Type                     Example
  #    * system_build_platform  - nerves_system_br
  #    * system                 - nerves_system_bbb
  #    * system_pkg             - nerves_pkg_alsa_utils
  #    * toolchain              - nerves_toolchain_arm_unknown_linux_gnueabihf
  defp load_packages do
    Mix.Project.deps_paths
    |> Enum.filter(fn({_, path}) ->
      Package.config_path(path)
      |> File.exists?
    end)
    |> Enum.map(&Package.load_config/1)
    |> validate_packages
  end

  defp get do
    Agent.get(__MODULE__, &(&1))
  end

  # We need to validate that the nerves deps present for the target satisfy
  #  certain conditions
  #  There should only be 1 system and 1 toolchain present.
  #  Otherwise, raose
  defp validate_packages(packages) do
    for type <- [:system, :toolchain] do
      packages_by_type(packages, type)
      |> validate_one(type)
    end
    packages
  end

  defp validate_one(packages, type) when length(packages) > 1 do
    packages = Enum.map(packages, &(Map.get(&1, :app)))
    raise """
    Your mix project cannot contain more than one #{type} for the target.
    Your dependancies for the target contian the following #{type}s:
    #{Enum.join(packages, ~s/ /)}
    """
  end
  defp validate_one(packages, _type), do: packages



  @doc """
  # Export environment variables used by Elixir, Erlang, C/C++ and other tools
  # so that they use Nerves toolchain parameters and not the host's.
  #
  # This list is built up partially by adding environment variables from project
  # as issues are identified since there's not a fixed convention for how these
  # are used. The Rebar project source code for compiling C ports was very helpful
  # initially.

  NERVES_SYSTEM
  NERVES_ROOT
  NERVES_TOOLCHAIN
  NERVES_SDK_IMAGES
  NERVES_SDK_SYSROOT

  CROSSCOMPILE
  REBAR_PLT_DIR=$NERVES_SDK_SYSROOT/usr/lib/erlang
  CC=$CROSSCOMPILE-gcc
  CXX=$CROSSCOMPILE-g++
  CFLAGS="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64  -pipe -Os"
  CXXFLAGS="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64  -pipe -Os"
  LDFLAGS=""
  STRIP=$CROSSCOMPILE-strip
  ERL_CFLAGS="-I$ERTS_DIR/include -I$ERL_INTERFACE_DIR/include"
  ERL_LDFLAGS="-L$ERTS_DIR/lib -L$ERL_INTERFACE_DIR/lib -lerts -lerl_interface -lei"
  REBAR_TARGET_ARCH=$(basename $CROSSCOMPILE)

  # Rebar naming
  ERL_EI_LIBDIR="$ERL_INTERFACE_DIR/lib"
  ERL_EI_INCLUDE_DIR="$ERL_INTERFACE_DIR/include"

  # erlang.mk naming
  ERTS_INCLUDE_DIR="$ERTS_DIR/include"
  ERL_INTERFACE_LIB_DIR="$ERL_INTERFACE_DIR/lib"
  ERL_INTERFACE_INCLUDE_DIR="$ERL_INTERFACE_DIR/include"
  """

  def bootstrap do
    nerves_system_path = System.get_env("NERVES_SYSTEM") || system_path()
    nerves_toolchain_path = System.get_env("NERVES_TOOLCHAIN") || toolchain_path()

    [{"NERVES_SYSTEM", nerves_system_path},
     {"NERVES_TOOLCHAIN", nerves_toolchain_path},
     {"NERVES_APP", File.cwd!}]
    |> Enum.each(fn({k, v}) ->
      unless File.dir?(v) do
        Mix.raise """
        #{k} is set to a path which does not exist:
        #{v}
        """
      end
      System.put_env(k, v)
    end)

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

  defp toolchain_path do
    toolchain = Nerves.Env.toolchain
    Nerves.Package.Artifact.dir(toolchain, toolchain)
  end

  defp system_path do
    system = Nerves.Env.system
    toolchain = Nerves.Env.toolchain
    Nerves.Package.Artifact.dir(system, toolchain)
  end

end
