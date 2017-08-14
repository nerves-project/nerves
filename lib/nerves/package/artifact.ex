defmodule Nerves.Package.Artifact do
  @moduledoc """
  Package artifacts are the product of compiling a package with a
  specific toolchain.

  """
  @base_dir Path.expand("~/.nerves/artifacts")

  @doc """
  Get the artifact name

  Requires the package and toolchain package to be supplied
  """
  @spec name(Nerves.Package.t, Nerves.Package.t) :: String.t
  def name(pkg, toolchain) do
    target_tuple =
      case pkg.type do
        :toolchain ->
          Nerves.Env.host_platform <> "-" <>
          Nerves.Env.host_arch
        _ ->
        toolchain.config[:target_tuple]
        |> to_string
      end
    "#{pkg.app}-#{pkg.version}.#{target_tuple}"
  end

  @doc """
  Get the base dir for where an artifact for a package should be stored.

  If a package is pulled in from hex, the base dir for an artifact will point
  to the NERVES_ARTIFACT_DIR or if undefined, `~/.nerves/artifacts`

  Packages which were obtained through other Mix SCM's such as path will
  have a base_dir local to the package path
  """
  @spec base_dir(Nerves.Package.t) :: String.t
  def base_dir(pkg) do
    case pkg.dep do
      local when local in [:path, :project] ->
        pkg.path
        |> Path.join(".nerves/artifacts")
      _ ->
        System.get_env("NERVES_ARTIFACTS_DIR") || @base_dir
    end

  end

  @doc """
  The full path to the artifact
  """
  @spec dir(Nerves.Package.t, Nerves.Package.t) :: String.t
  def dir(pkg, toolchain) do
    if env_var?(pkg) do
      System.get_env(env_var(pkg)) |> Path.expand
    else
      base_dir(pkg)
      |> Path.join(name(pkg, toolchain))
    end
  end

  @doc """
  Determines if an artifact exists at its artifact dir.
  """
  @spec exists?(Nerves.Package.t, Nerves.Package.t) :: boolean
  def exists?(pkg, toolchain) do
    dir(pkg, toolchain)
    |> File.dir?
  end

  @doc """
  Check to see if the artifact path is being set from the system env
  """
  @spec env_var?(Nerves.Package.t) :: boolean
  def env_var?(pkg) do
    name = env_var(pkg)
    dir = System.get_env(name)
    dir != nil and File.dir?(dir)
  end

  @doc """
  Determine the environment variable which would be set to override the path
  """
  @spec env_var(Nerves.Package.t) :: String.t
  def env_var(pkg) do
    case pkg.type do
      :toolchain -> "NERVES_TOOLCHAIN"
      :system -> "NERVES_SYSTEM"
      _ ->
        pkg.name
        |> Atom.to_string
        |> String.upcase
    end
  end

  @doc """
  Determines the extension for an artifact based off its type.
  Toolchains use xz compression
  """
  @spec ext(Nerves.Package.t) :: String.t
  def ext(%{type: :toolchain}), do: "tar.xz"
  def ext(_), do: "tar.gz"

end
