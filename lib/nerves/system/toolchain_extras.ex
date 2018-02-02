defmodule Nerves.System.ToolchainExtras do
  use Nerves.Package.Platform

  alias Nerves.Artifact
  import Mix.Nerves.Utils

  @doc """
  Called as the last step of bootstrapping the Nerves env.
  """
  def bootstrap(%{path: path} = pkg) do
    build_path = Artifact.base_dir() |> Path.join(Artifact.name(pkg))
    env_var = pkg.config[:toolchain_extras][:env_var]
    IO.puts "extras:bootsrapping: \n\t pkg: #{inspect pkg} \n\t build_path: #{inspect build_path}"
    IO.puts "extras:bootsrapping: put_env: envvar: #{inspect env_var}"
    System.put_env(env_var, build_path)
    IO.puts "extras:bootsrapping: get_env: #{inspect System.get_env() }"
    :ok
  end

  @doc """
  Build the artifact
  """
  def build(pkg, _toolchain, _opts) do
    build_path = Artifact.build_path(pkg)
    #File.rm_rf!(build_path)
    #File.mkdir_p!(build_path)


    script =
      build_path
      |> Path.join(pkg.config[:toolchain_extras][:build_script])

    IO.puts "extras.prucgt:build: build_script: #{inspect script} toolchain: #{inspect _toolchain}, opts: #{inspect _opts}"

    # defconfig = defconfig(pkg)

    # case shell(script, [defconfig, build_path]) do
    #   {_, 0} -> 
    #     x_tools = Path.join(build_path, "x-tools")
    #     tuple = 
    #       x_tools
    #       |> File.ls!
    #       |> List.first
    #     toolchain_path = Path.join(x_tools, tuple)
    #     {:ok, toolchain_path}
    #   {error, _} -> {:error, error}
    # end

    :ok
  end

  @doc """
  Return the location in the build path to where the global artifact is linked
  """
  def build_path_link(pkg) do
    IO.inspect Artifact.build_path(pkg) |> Path.join(pkg.config[:build_path_link]), lable: :extras_build_path_link
  end

  @doc """
  Create an archive of the artifact
  """
  def archive(pkg, _toolchain, _opts) do
    build_path = Artifact.build_path(pkg)

    IO.puts "extras.prucgt:archive: toolchain: #{inspect _toolchain}, opts: #{inspect _opts}"

    script =
      :nerves_toolchain_ctng
      |> Nerves.Env.package()
      |> Map.get(:path)
      |> Path.join("scripts")
      |> Path.join("archive.sh")

    # tar_path = Path.join([build_path, Artifact.name(pkg) <> Artifact.ext(pkg)])

    # case shell(script, [build_path, tar_path]) do
    #   {_, 0} -> {:ok, tar_path}
    #   {error, _} -> {:error, error}
    # end
    :ok
  end

  @doc """
  Clean up all the build files
  """
  def clean(pkg) do
    # dmg = Artifact.name(pkg) <> ".dmg"
    # File.rm(dmg)

    # pkg
    # |> Artifact.dir()
    # |> File.rm_rf()
    :ok
  end

  defp defconfig(pkg) do
    pkg.config
    |> Keyword.get(:platform_config)
    |> Keyword.get(:defconfig)
    |> Path.expand
  end
  
end
