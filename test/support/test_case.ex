defmodule NervesTest.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__)
      alias NervesTest.Case
    end
  end

  setup do
    Application.stop(:nerves_bootstrap)

    on_exit(fn ->
      Mix.env(:dev)
      Mix.Task.clear()
      Mix.Shell.Process.flush()
      Mix.ProjectStack.clear_cache()
      Mix.ProjectStack.clear_stack()
      delete_tmp_paths()
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

    System.put_env("XDG_DATA_HOME", tmp_path(tmp))

    try do
      File.cd!(dest, function)
    after
      unload_env()
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
    Path.expand("../../test_tmp", __DIR__)
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
    Application.ensure_all_started(:nerves_bootstrap)

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
    case Process.whereis(Nerves.Env) do
      nil ->
        :ok

      _ ->
        packages =
          Nerves.Env.packages()
          |> Enum.sort()

        Enum.each(packages, fn %{app: app} ->
          key = {:cached_deps, Mix.env(), app}
          Agent.cast(Mix.ProjectStack, &%{&1 | cache: Map.delete(&1.cache, key)})
        end)
    end
  end

  defp delete_tmp_paths do
    tmp = String.to_charlist(tmp_path())
    for path <- :code.get_path(), :string.str(path, tmp) != 0, do: :code.del_path(path)
  end
end
