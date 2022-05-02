defmodule NervesTest.Case do
  @moduledoc false

  use ExUnit.CaseTemplate, async: false

  @compile {:no_warn_undefined, {Mix, :target, 0}}
  @compile {:no_warn_undefined, {Mix.State, :clear_cache, 0}}
  @compile {:no_warn_undefined, {Mix.ProjectStack, :clear_cache, 0}}
  @timeout_before_close_check 20

  using do
    quote do
      import unquote(__MODULE__)
      alias NervesTest.Case
    end
  end

  setup do
    Application.stop(:nerves_bootstrap)
    original_env = System.get_env()

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
      reset_system_env(original_env)
      Nerves.Env.stop()

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

    tmp_path =
      tmp
      |> String.replace(":", "_")
      |> String.replace(" ", "_")

    dest = tmp_path(tmp_path)
    flag = String.to_charlist(tmp_path())

    System.put_env("XDG_DATA_HOME", Path.join(dest, ".nerves"))

    _ = File.rm_rf!(dest)
    File.mkdir_p!(dest)
    _ = File.cp_r!(src, dest)

    get_path = :code.get_path()
    previous = :code.all_loaded()

    try do
      File.cd!(dest, function)
      :timer.sleep(10)
    after
      true = :code.set_path(get_path)

      for {mod, file} <- :code.all_loaded() -- previous,
          file == [] or (is_list(file) and List.starts_with?(file, flag)) do
        purge([mod])
      end

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
    _ = File.rm_rf!(path)
    File.mkdir_p!(path)
    File.cd!(path, function)
  end

  @spec test_path(Path.t()) :: Path.t()
  def test_path(cmd) do
    Path.join([File.cwd!(), "test", cmd])
  end

  def fixture_path() do
    Path.expand("../fixtures", __DIR__)
  end

  def fixture_path(extension) do
    Path.join(fixture_path(), extension)
  end

  def tmp_path() do
    Path.expand("../../test_tmp", __DIR__)
  end

  def tmp_path(extension) do
    Path.join(tmp_path(), to_string(extension))
  end

  def fixture_to_tmp(fixture, dest) do
    src = fixture_path(fixture)

    _ = File.rm_rf!(dest)
    File.mkdir_p!(dest)
    File.cp_r!(src, dest)
  end

  def load_env(packages \\ []) do
    {:ok, _} = Application.ensure_all_started(:nerves_bootstrap)

    packages =
      packages
      |> Enum.sort()

    Enum.each(packages, fn package ->
      path = Path.expand("#{File.cwd!()}/../#{package}")
      fixture_to_tmp(package, path)
    end)

    _ = Code.require_file(Path.expand("mix.exs"))

    {:ok, _} = Nerves.Env.start()
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

  defp reset_system_env(env) do
    System.get_env()
    |> Enum.reject(&Map.get(env, elem(&1, 0) != nil))
    |> Enum.each(&System.put_env(elem(&1, 0), elem(&1, 1)))
  end

  defp delete_tmp_paths() do
    tmp = String.to_charlist(tmp_path())

    :code.get_path()
    |> Enum.filter(fn path -> :string.str(path, tmp) != 0 end)
    |> Enum.each(&:code.del_path/1)
  end

  defp elixir_minor() do
    System.version() |> Version.parse!() |> Map.get(:minor)
  end

  @spec os_process_alive?(non_neg_integer()) :: boolean
  def os_process_alive?(os_pid) do
    {_, rc} = System.cmd("ps", ["-p", "#{os_pid}"])
    rc == 0
  end

  @spec os_pid(port()) :: non_neg_integer()
  def os_pid(port) do
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    os_pid
  end

  @spec wait_for_close_check(non_neg_integer()) :: :ok
  def wait_for_close_check(timeout \\ @timeout_before_close_check) do
    Process.sleep(timeout)
  end
end
