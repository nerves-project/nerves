defmodule Nerves.Package.Artifact do

  @dir Path.expand("~/.nerves/artifacts")

  def get(pkg, toolchain) do
    Nerves.Package.Provider.artifact(pkg, toolchain)
  end

  def name(pkg, toolchain) do
    target_tuple =
      case pkg.type do
        :toolchain ->
          {_, host} = :os.type
          arch = Nerves.Env.host_arch
          "#{host}-#{arch}"
        _ ->
        toolchain.target_tuple
        |> to_string
      end
    "#{pkg.app}-#{pkg.version}.#{target_tuple}"
  end

  def dir(pkg, toolchain) do
    (System.get_env("NERVES_ARTIFACTS_DIR") || @dir)
    |> IO.inspect
    |> Path.join(name(pkg, toolchain))
  end

  def exists?(pkg, toolchain) do
    dir(pkg, toolchain)
    |> File.exists?
  end

  def ext(%{type: :toolchain}), do: "tar.xz"

end
