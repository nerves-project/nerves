defmodule NervesTest.Case do
  use ExUnit.CaseTemplate

  @compile {:no_warn_undefined, {Mix, :target, 0}}
  @compile {:no_warn_undefined, {Mix.State, :clear_cache, 0}}
  @compile {:no_warn_undefined, {Mix.ProjectStack, :clear_cache, 0}}

  using do
    quote do
      import unquote(__MODULE__)
      alias NervesTest.Case
    end
  end

  setup do
    Application.stop(:nerves_bootstrap)

    on_exit(fn ->
      Application.start(:logger)
      Mix.env(:dev)

      if elixir_minor() > 8 do
        apply(Mix, :target, [:host])
      end

      Mix.Task.clear()
      Mix.Shell.Process.flush()

      # < Elixir 1.10.0
      if elixir_minor() < 10 do
        Mix.ProjectStack.clear_cache()
      else
        Mix.State.clear_cache()
      end

      Mix.ProjectStack.clear_stack()
      delete_tmp_paths()

      :ok
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
    src = fixture_path(which)
    dest = tmp_path(String.replace(tmp, ":", "_"))
    flag = String.to_charlist(tmp_path())

    System.put_env("XDG_DATA_HOME", Path.join(dest, ".nerves"))

    File.rm_rf!(dest)
    File.mkdir_p!(dest)
    File.cp_r!(src, dest)

    get_path = :code.get_path()
    previous = :code.all_loaded()

    try do
      File.cd!(dest, function)
    after
      :code.set_path(get_path)

      for {mod, file} <- :code.all_loaded() -- previous,
          file == [] or (is_list(file) and List.starts_with?(file, flag)) do
        purge([mod])
      end

      System.delete_env("XDG_DATA_HOME")

      if elixir_minor() < 10 do
        unload_env()
      end
    end
  end

  def purge(modules) do
    Enum.each(modules, fn m ->
      :code.purge(m)
      :code.delete(m)
    end)
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

  defp elixir_minor() do
    System.version() |> Version.parse!() |> Map.get(:minor)
  end
end
