defmodule Nerves.Package.Artifact do

  @base_dir Path.expand("~/.nerves/artifacts")

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

  def base_dir(pkg) do
    case pkg.dep do
      local when local in [:path, :project] ->
        pkg.path
        |> Path.join(".nerves/artifacts")
      _ ->
        System.get_env("NERVES_ARTIFACTS_DIR") || @base_dir
    end

  end

  def dir(pkg, toolchain) do
    base_dir(pkg)
    |> Path.join(name(pkg, toolchain))
    |> protocol_vsn(pkg)
  end

  defp protocol_vsn(dir, pkg) do
    if pkg.compiler == :nerves_package do
      dir
    else
      build_path =
        Mix.Project.build_path
        |> Path.join("nerves")
        |> Path.expand
        case pkg.type do
        :toolchain ->
          Path.join(build_path, "toolchain")
        :system ->
          Path.join(build_path, "system")
        type -> Mix.raise "Cannot determine artifact path for #{type}"
      end
    end
  end

  def exists?(pkg, toolchain) do
    dir(pkg, toolchain)
    |> File.dir?
  end

  def ext(%{type: :toolchain}), do: "tar.xz"

end
