defmodule NervesTest.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__)
      alias NervesTest.Case
    end
  end

  setup config do
    if apps = config[:apps] do
      Logger.remove_backend(:console)
    end

    on_exit(fn ->
      Application.start(:logger)
      Mix.env(:dev)
      Mix.Task.clear()
      Mix.Shell.Process.flush()
      Mix.ProjectStack.clear_cache()
      Mix.ProjectStack.clear_stack()
      delete_tmp_paths()

      if apps do
        for app <- apps do
          Application.stop(app)
          Application.unload(app)
        end

        Logger.add_backend(:console, flush: true)
      end
    end)

    :ok
  end

  defmacro in_fixture(which, block) do
    module = inspect(__CALLER__.module)
    function = Atom.to_string(elem(__CALLER__.function, 0))
    tmp = Path.join(module, function)

    quote do
      unquote(__MODULE__).in_fixture(unquote(which), unquote(tmp), unquote(block))
    end
  end

  def in_fixture(which, tmp, function) do
    dest =
      tmp_path(tmp)
      |> Path.join(which)

    fixture_to_tmp(which, dest)

    artifact_dir = Path.join(tmp_path(tmp), ".nerves/artifacts")
    download_dir = Path.join(tmp_path(tmp), ".nerves/dl")

    System.put_env("NERVES_ARTIFACTS_DIR", artifact_dir)
    System.put_env("NERVES_DL_DIR", download_dir)

    try do
      File.cd!(dest, function)
    after
      # unload_env()
    end
  end

  def in_tmp(which, function) do
    path = tmp_path(which)
    File.rm_rf!(path)
    File.mkdir_p!(path)
    File.cd!(path, function)
  end

  def fixture_path do
    Path.expand("../fixtures", __DIR__)
  end

  def fixture_path(extension) do
    Path.join(fixture_path(), extension)
  end

  def tmp_path do
    Path.expand("../tmp", __DIR__)
  end

  def tmp_path(extension) do
    Path.join(tmp_path(), to_string(extension))
  end

  def fixture_to_tmp(fixture, dest) do
    src = fixture_path(fixture)

    File.rm_rf!(dest)
    File.mkdir_p!(dest)
    File.cp_r!(src, dest)
  end

  def load_env(packages \\ []) do
    packages =
      packages
      |> Enum.sort()

    Enum.each(packages, fn package ->
      path = Path.expand("#{File.cwd!()}/../#{package}")
      fixture_to_tmp(package, path)
    end)

    File.cwd!()
    |> Path.join("mix.exs")
    |> Code.require_file()

    Nerves.Env.start()
    Nerves.Env.packages()
  end

  def unload_env() do
    packages =
      Nerves.Env.packages()
      |> Enum.sort()

    Enum.each(packages, fn %{app: app} ->
      key = {:cached_deps, Mix.env(), app}
      Agent.cast(Mix.ProjectStack, &%{&1 | cache: Map.delete(&1.cache, key)})
    end)
  end

  defp delete_tmp_paths do
    tmp = String.to_charlist(tmp_path())
    for path <- :code.get_path(), :string.str(path, tmp) != 0, do: :code.del_path(path)
  end
end
