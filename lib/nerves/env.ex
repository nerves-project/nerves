defmodule Nerves.Env do
  @config "nerves.exs"
  @default_files ~w(config lib priv mix.exs src)

  alias __MODULE__

  defmodule Dep do
    defstruct [app: nil,  path: nil, type: nil, config: []]

    @type t :: %__MODULE__{app: atom,
                          path: binary,
                          type: :system |
                                :package |
                                :toolchain
                        config: Keyword.t}
  end

  def initialize do
    Agent.start_link fn -> deps_load end, name: __MODULE__
  end

  def stop do
    Agent.stop(__MODULE__)
  end

  def deps do
    get || raise "Nerves Deps are not loaded"
  end

  def dep(name) do
    deps
    |> Enum.filter(& &1.app == name)
    |> List.first
  end

  def deps_by_type(type) do
    deps
    |> deps_by_type(type)
  end

  def deps_by_type(deps, type) do
    deps
    |> Enum.filter(& &1.type == type)
  end

  def stale? do
    system_manifest =
      system_path
      |> Path.join(".nerves.lock")
      |> Path.expand

    if stale_check_manifest(system_manifest) do
      [system | system_exts]
      |> Enum.map(fn (%{path: path, config: config}) ->
        (config[:package_files] || @default_files)
        |> expand_paths(path)
        |> Enum.map(& Path.join(path, &1))
      end)
      |> Enum.any?(& Mix.Utils.stale?(&1, [system_manifest]))
    else
      true
    end
  end

  def stale_check_manifest(manifest) do
    case File.read(manifest) do
      {:ok, file} ->
        file
        |> :erlang.binary_to_term
        |> Keyword.equal?(Env.deps)
      _ -> false
    end
  end

  def system do
    deps_by_type(:system)
    |> List.first
  end

  def system_platform do
    system.config[:build_platform]
  end

  def system_exts do
    deps_by_type(:system_ext)
  end

  def toolchain do
    deps_by_type(:toolchain)
    |> List.first
  end

  def serialize do
    file =
      File.cwd!
      |> Path.join("nerves_env.tar.gz")

    {files, manifests} =
      deps
      |> Enum.reduce({[], []}, fn(%{app: app, path: path, config: config} = dep, {files, manifests}) ->
        default_files = config[:package_files] || @default_files

        dep_manifest = %{
          app: app,
          type: dep.type,
          path: "#{app}"
        }
        expand_dir = Path.expand(path)
        paths =
          expand_paths(default_files, path)
          |> Enum.map(fn(path)  ->
            tar_path =
              "#{app}/#{path}"
              |> String.to_char_list
            local_path =
              Path.join(expand_dir, path)
              |> String.to_char_list
            {tar_path, local_path}
          end)
        {paths ++ files, [dep_manifest | manifests]}
      end)
    manifest =
      {String.to_char_list("nerves_env/manifest.config"), :erlang.term_to_binary(manifests)}

    case :erl_tar.create(file, files ++ [manifest], [:compressed]) do
      :ok -> {:ok, file}
      error -> error
    end
  end

  def expand_paths(paths, dir) do
    expand_dir = Path.expand(dir)

    paths
    |> Enum.map(&Path.join(dir, &1))
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.flat_map(&dir_files/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.filter(&File.regular?/1)
    |> Enum.uniq
    |> Enum.map(&Path.relative_to(&1, expand_dir))
  end

  defp dir_files(path) do
    if File.dir?(path) do
      Path.wildcard(Path.join(path, "**"))
    else
      [path]
    end
  end

  # Collect all deps containing #{dep_path}/nerves.exs
  # Each Nerves Dep
  #  * Load the nerves.exs
  #  * Determine the project type
  #    Type                     Example
  #    * system_compiler        - nerves_system
  #    * system_build_platform  - nerves_system_br
  #    * system                 - nerves_system_bbb
  #    * system_ext             - nerves_bluetooth
  #    * toolchain_compiler     - nerves_toolchain
  #    * toolchain              - nerves_toolchain_arm_unknown_linux_gnueabihf
  defp deps_load do
    Mix.Project.deps_paths
    |> Map.put_new(Mix.Project.config[:app], File.cwd!)
    |> Enum.filter(fn({_, path}) ->
      config_path(path)
      |> File.exists?
    end)
    |> Enum.reduce([], fn({app, path}, acc) ->
      load_nerves_config(path)
      config = Application.get_env(app, :nerves_env)
      [%Dep{app: app, type: config[:type], path: path, config: config} | acc]
    end)
    |> validate_deps
  end

  defp get do
    Agent.get(__MODULE__, &(&1))
  end

  # We need to validate that the nerves deps present for the target satisfy
  #  certain conditions
  #  There should only be 1 system and 1 toolchain present.
  #  Otherwise, raose
  defp validate_deps(deps) do
    for type <- [:system, :toolchain] do
      deps_by_type(deps, type)
      |> validate_one(type)
    end
    deps
  end

  defp validate_one(deps, type) when length(deps) > 1 do
    deps = Enum.map(deps, &(Map.get(&1, :app)))
    raise """
    Your mix project cannot contain more than one #{type} for the target.
    Your dependancies for the target contian the following #{type}s:
    #{Enum.join(deps, ~s/ /)}
    """
  end
  defp validate_one(deps, _type), do: deps

  defp config_path(path) do
    Path.join(path, @config)
  end

  def load_nerves_config(path) do
    config_path(path)
    |> Mix.Config.read!
    |> Mix.Config.persist
  end

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
  require Logger
  def bootstrap do
    Logger.debug "SYSTEM: #{System.get_env("NERVES_SYSTEM") || system_path}"
    [{"NERVES_SYSTEM", System.get_env("NERVES_SYSTEM") || system_path},
     {"NERVES_TOOLCHAIN", System.get_env("NERVES_TOOLCHAIN") || toolchain_path},
     {"NERVES_APP", File.cwd!}]
    |> Enum.each(fn({k, v}) -> System.put_env(k, v) end)

    # Bootstrap the build platform
    platform = Env.system.config[:build_platform] || raise Nerves.System.Exception, message: "You must specify a build_platform in the nerves.exs config for the system #{Env.system.app}"
    platform.bootstrap
  end

  defp toolchain_path do
    Mix.Project.build_path
    |> Path.join("nerves/toolchain")
  end

  defp system_path do
    case System.get_env("NERVES_SYSTEM_CACHE") do
      "local" ->
        Nerves.System.Providers.Local.system_cache_dir
        |> Path.join("#{Env.system.app}-#{Env.system.config[:version]}")
      _ ->
        Mix.Project.build_path
        |> Path.join("nerves/system")
    end

  end

end
