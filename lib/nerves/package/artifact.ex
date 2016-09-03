defmodule Nerves.Package.Artifact do

  @base_dir Path.expand("~/.nerves/artifacts")

  def name(pkg, toolchain) do
    target_tuple =
      case pkg.type do
        :toolchain ->
          {_, host} = :os.type
          arch = Nerves.Env.host_arch
          "#{host}-#{arch}"
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
  end

  def exists?(pkg, toolchain) do
    dir(pkg, toolchain)
    |> File.exists?
  end

  def ext(%{type: :toolchain}), do: "tar.xz"

end
