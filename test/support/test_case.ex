# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
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

      :ok
    end)

    :ok
  end

  defmacro in_fixture(which, block) do
    module = inspect(__CALLER__.module)
    {function, _} = __CALLER__.function
    tmp = Path.join(module, Atom.to_string(function))

    quote do
      unquote(__MODULE__).in_fixture(unquote(which), unquote(tmp), unquote(block))
    end
  end

  @spec in_fixture(Path.t(), Path.t(), function()) :: :ok | nil
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

  @doc """
  Compile a test fixture with it's dependencies to a temporary directory

  Returns the temporary path of the copied fixture and environment variables
  list with `XDG_DATA_HOME` set to `tmp_path/.nerves` for an isolated
  Nerves data directory if needed (i.e. With `System.cmd` or Nerves)

  The `tmp` argument can be any directory, though it is suggested to use the
  `ExUnit.Case` Tmp Dir functionality with `@tag :tmp_dir` which will handle
  creation of a clean directory for the test.

  ```
  @tag :tmp_dir
  test "something", %{temp_dir: tmp} do
    {path, env} = setup_fixture("some_app", tmp)
  end
  ```

  See https://hexdocs.pm/ex_unit/ExUnit.Case.html#module-tmp-dir
  """
  @type env_var :: {String.t(), String.t()}
  @spec compile_fixture(String.t(), Path.t(), [String.t()], [env_var()]) ::
          {:ok, Path.t(), [env_var()]} | {Collectable.t(), exit_status :: non_neg_integer()}
  def compile_fixture(fixture, tmp, deps \\ [], env \\ [{"MIX_TARGET", "test"}]) do
    src = fixture_path(fixture)

    dest = Path.join(tmp, fixture) |> Path.expand()

    env = [{"XDG_DATA_HOME", Path.join(dest, ".nerves")} | env]

    _ = File.cp_r!(src, dest)

    Enum.each(deps, fn dep ->
      path = Path.expand("#{dest}/../#{dep}")
      fixture_to_tmp(dep, path)
    end)

    opts = [cd: dest, env: env, stderr_to_stdout: true]

    with {_deps, 0} <- System.cmd("mix", ["deps.get"], opts),
         {_compile, 0} <- System.cmd("mix", ["compile"], opts) do
      {:ok, dest, env}
    end
  end

  @doc """
  Same as `compile_fixture/4` but raises on error
  """
  @spec compile_fixture!(String.t(), Path.t(), [String.t()], [env_var()]) ::
          {Path.t(), [env_var()]} | :no_return
  def compile_fixture!(fixture, tmp, deps \\ [], env \\ [{"MIX_TARGET", "test"}]) do
    case compile_fixture(fixture, tmp, deps, env) do
      {:ok, dest, env} ->
        {dest, env}

      {output, err} ->
        msg =
          [
            "Fixture compilation error during integration test. See output below ¬",
            "\n\n=== Start ===\n\n",
            output,
            "\n\n=== End ==="
          ]
          |> IO.iodata_to_binary()

        if function_exported?(Mix, :raise, 2) do
          # since 1.12.3
          Mix.raise(msg, exit_status: err)
        else
          Mix.raise(msg)
        end
    end
  end

  @spec purge([module()]) :: :ok
  def purge(modules) do
    Enum.each(modules, fn m ->
      :code.purge(m)
      :code.delete(m)
    end)
  end

  @spec in_tmp(Path.t(), function()) :: :ok
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

  @spec fixture_path() :: Path.t()
  def fixture_path() do
    Path.expand("../fixtures", __DIR__)
  end

  @spec fixture_path(Path.extname()) :: Path.t()
  def fixture_path(extension) do
    Path.join(fixture_path(), extension)
  end

  @spec tmp_path() :: Path.t()
  def tmp_path() do
    Path.expand("../../test_tmp", __DIR__)
  end

  @spec tmp_path(Path.extname()) :: Path.t()
  def tmp_path(extension) do
    Path.join(tmp_path(), to_string(extension))
  end

  @spec fixture_to_tmp(Path.t(), Path.t()) :: :ok
  def fixture_to_tmp(fixture, dest) do
    src = fixture_path(fixture)

    _ = File.rm_rf!(dest)
    File.mkdir_p!(dest)
    File.cp_r!(src, dest)
  end

  @spec load_env([String.t()]) :: [Nerves.Package.t()]
  def load_env(packages \\ []) do
    packages =
      packages
      |> Enum.sort()

    Enum.each(packages, fn package ->
      path = Path.expand("#{File.cwd!()}/../#{package}")
      fixture_to_tmp(package, path)
    end)

    _ = Code.require_file(Path.expand("mix.exs"))

    # TODO: Move this next line to a more appropriate place
    Nerves.Env.set_source_date_epoch()
    Nerves.Env.packages()
  end

  @spec unload_env() :: :ok
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
