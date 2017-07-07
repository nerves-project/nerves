defmodule Nerves.Bootstrap.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_bootstrap,
     version: "0.5.1",
     elixir: "~> 1.4.0",
     aliases: aliases(),
     xref: [exclude: [Nerves.Env]]]
  end

  def application do
    [extra_applications: []]
  end

  def aliases do
    ["compile.elixir": [&unload_bootstrap/1, "compile.elixir"],
     run: [&unload_bootstrap/1, "run"],
     install: ["archive.build -o nerves_bootstrap.ez", "archive.install nerves_bootstrap.ez --force"]]
  end

  defp unload_bootstrap(_) do
    Application.stop(:nerves_bootstrap)
    paths = Path.wildcard(Path.join(archives_path(), "nerves_bootstrap*"))

    Enum.each(paths, fn archive ->
      ebin = archive_ebin(archive)
      Code.delete_path(ebin)

      {:ok, files} = ebin |> :unicode.characters_to_list |> :erl_prim_loader.list_dir

      Enum.each(files, fn file ->
        file = List.to_string(file)
        size = byte_size(file) - byte_size(".beam")

        case file do
          <<name :: binary-size(size), ".beam">> ->
            module = String.to_atom(name)
            :code.delete(module)
            :code.purge(module)
          _ ->
            :ok
        end
      end)
    end)
  end

  defp archives_path do
    if function_exported?(Mix.Local, :path_for, 1),
      do: Mix.Local.path_for(:archive),
    else: Mix.Local.archives_path
  end

  defp archive_ebin(archive) do
    if function_exported?(Mix.Local, :archive_ebin, 1),
      do: Mix.Local.archive_ebin(archive),
    else: Mix.Archive.ebin(archive)
  end

end
