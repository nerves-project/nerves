# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.RemoveMixTasksTest do
  # async: false since some tests change the :nerves application environment
  use ExUnit.Case, async: false

  alias Nerves.BuildAction.RemoveMixTasks
  alias Nerves.BuildPlan

  @my_lib_modules [MyLib, MyLib.Worker, Mix.Tasks.MyLib.Install, Mix.Tasks.MyLib.Gen.Thing]
  @mix_modules [Mix, Mix.Task, Mix.Tasks.Compile]
  @other_modules [Other, Other.Mix.Tasks.NotATask]

  setup do
    original = Application.fetch_env(:nerves, :remove_mix_tasks)

    on_exit(fn ->
      case original do
        {:ok, value} -> Application.put_env(:nerves, :remove_mix_tasks, value)
        :error -> Application.delete_env(:nerves, :remove_mix_tasks)
      end
    end)

    Application.delete_env(:nerves, :remove_mix_tasks)
  end

  @tag :tmp_dir
  test "removes Mix task beams and all references to them", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)

    new_release = RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, [])

    # Beams
    assert beams(release, "my_lib-1.0.0") == ["Elixir.MyLib.Worker.beam", "Elixir.MyLib.beam"]

    assert beams(release, "other-0.1.0") == [
             "Elixir.Other.Mix.Tasks.NotATask.beam",
             "Elixir.Other.beam"
           ]

    # .app files
    assert {:application, :my_lib, my_lib_properties} = read_app(release, "my_lib-1.0.0")
    assert my_lib_properties[:modules] == [MyLib, MyLib.Worker]
    assert my_lib_properties[:vsn] == ~c"1.0.0"
    assert my_lib_properties[:description] == ~c"my_lib ünïcödé"
    assert my_lib_properties[:mod] == {MyLib, []}

    assert {:application, :other, other_properties} = read_app(release, "other-0.1.0")
    assert other_properties[:modules] == @other_modules

    # Boot scripts
    for name <- ["start", "start_clean"] do
      boot = read_boot(release, name)
      assert boot == read_script(release, name)

      assert prim_loaded(boot) == [MyLib, MyLib.Worker] ++ @mix_modules ++ @other_modules
      assert loaded_app_modules(boot, :my_lib) == [MyLib, MyLib.Worker]
      assert loaded_app_modules(boot, :other) == @other_modules

      # Everything else is untouched
      assert {:script, {~c"test", ~c"0.1.0"}, instructions} = boot
      assert {:progress, :preloaded} in instructions
      assert {:path, [~c"$ROOT/lib/my_lib-1.0.0/ebin"]} in instructions
      assert {:apply, {:application, :start_boot, [:my_lib, :temporary]}} in instructions
    end

    # Release struct
    assert new_release.applications[:my_lib][:modules] == [MyLib, MyLib.Worker]
    assert new_release.applications[:other][:modules] == @other_modules
    assert %{new_release | applications: release.applications} == release
  end

  @tag :tmp_dir
  test "leaves the mix application alone by default", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)

    new_release = RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, [])

    assert "Elixir.Mix.Tasks.Compile.beam" in beams(release, "mix-1.20.0")
    assert {:application, :mix, properties} = read_app(release, "mix-1.20.0")
    assert properties[:modules] == @mix_modules
    assert loaded_app_modules(read_boot(release, "start"), :mix) == @mix_modules
    assert new_release.applications[:mix][:modules] == @mix_modules
  end

  @tag :tmp_dir
  test "exclude option selects which applications to skip", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)

    _ = RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, exclude: [:my_lib])

    assert length(beams(release, "my_lib-1.0.0")) == 4
    assert beams(release, "mix-1.20.0") == ["Elixir.Mix.Task.beam", "Elixir.Mix.beam"]

    boot = read_boot(release, "start")
    assert prim_loaded(boot) == @my_lib_modules ++ [Mix, Mix.Task] ++ @other_modules
    assert loaded_app_modules(boot, :mix) == [Mix, Mix.Task]
  end

  @tag :tmp_dir
  test "exclude can be set in the application environment", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)
    Application.put_env(:nerves, :remove_mix_tasks, exclude: [:mix, :my_lib])

    assert RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, []) == release
    assert length(beams(release, "my_lib-1.0.0")) == 4
  end

  @tag :tmp_dir
  test "can be disabled in the application environment", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)
    before = snapshot(release)
    Application.put_env(:nerves, :remove_mix_tasks, false)

    assert RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, []) == release
    assert snapshot(release) == before
  end

  @tag :tmp_dir
  test "can be disabled with an option", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)
    before = snapshot(release)

    assert RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, enabled: false) == release
    assert snapshot(release) == before
  end

  @tag :tmp_dir
  test "raises on bad application environment", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)
    Application.put_env(:nerves, :remove_mix_tasks, :nope)

    assert_raise Mix.Error, ~r/remove_mix_tasks/, fn ->
      RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, [])
    end
  end

  @tag :tmp_dir
  test "is idempotent and doesn't rewrite files when there's nothing to do", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)

    new_release = RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, [])
    before = snapshot(release)

    assert RemoveMixTasks.post_assemble_steps(%BuildPlan{}, new_release, []) == new_release
    assert snapshot(release) == before
  end

  @tag :tmp_dir
  test "works when boot script sources were already trimmed", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)
    Path.wildcard("#{release.path}/releases/**/*.script") |> Enum.each(&File.rm!/1)

    _ = RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, [])

    assert loaded_app_modules(read_boot(release, "start"), :my_lib) == [MyLib, MyLib.Worker]
    assert Path.wildcard("#{release.path}/releases/**/*.script") == []
  end

  @tag :tmp_dir
  test "removes stray beams that aren't listed in the .app file", %{tmp_dir: tmp_dir} do
    release = make_release(tmp_dir)
    ebin = Path.join(release.path, "lib/other-0.1.0/ebin")
    File.write!(Path.join(ebin, "Elixir.Mix.Tasks.Stray.beam"), "beam")
    app_before = File.read!(Path.join(ebin, "other.app"))

    _ = RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, [])

    refute File.exists?(Path.join(ebin, "Elixir.Mix.Tasks.Stray.beam"))
    assert File.read!(Path.join(ebin, "other.app")) == app_before
  end

  @tag :tmp_dir
  test "raises when passed a bad path", %{tmp_dir: tmp_dir} do
    release = %Mix.Release{name: :test, version: "0.1.0", path: Path.join(tmp_dir, "missing")}

    assert_raise Mix.Error, ~r/to contain an Erlang\/OTP release/, fn ->
      RemoveMixTasks.post_assemble_steps(%BuildPlan{}, release, [])
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp make_release(tmp_dir) do
    release_path = Path.join(tmp_dir, "release")

    apps = [
      {:my_lib, ~c"1.0.0", @my_lib_modules},
      {:mix, ~c"1.20.0", @mix_modules},
      {:other, ~c"0.1.0", @other_modules}
    ]

    app_specs =
      for {app, vsn, modules} <- apps do
        ebin = Path.join(release_path, "lib/#{app}-#{vsn}/ebin")
        File.mkdir_p!(ebin)
        Enum.each(modules, &File.write!(Path.join(ebin, "#{&1}.beam"), "beam"))

        properties = [
          description: ~c"#{app} ünïcödé",
          vsn: vsn,
          modules: modules,
          registered: [],
          applications: [:kernel, :stdlib],
          mod: {MyLib, []}
        ]

        spec = {:application, app, properties}
        write_term(Path.join(ebin, "#{app}.app"), spec)
        spec
      end

    script =
      {:script, {~c"test", ~c"0.1.0"},
       [
         {:preLoaded, [:erlang, :init]},
         {:progress, :preloaded},
         {:path, [~c"$ROOT/lib/my_lib-1.0.0/ebin"]},
         {:primLoad, @my_lib_modules},
         {:path, [~c"$ROOT/lib/mix-1.20.0/ebin"]},
         {:primLoad, @mix_modules ++ @other_modules},
         {:kernel_load_completed},
         {:progress, :kernel_load_completed}
       ] ++
         Enum.map(app_specs, &{:apply, {:application, :load, [&1]}}) ++
         [
           {:progress, :applications_loaded},
           {:apply, {:application, :start_boot, [:my_lib, :temporary]}},
           {:progress, :started}
         ]}

    releases = Path.join(release_path, "releases/0.1.0")
    File.mkdir_p!(releases)

    for name <- ["start", "start_clean"] do
      write_term(Path.join(releases, "#{name}.script"), script)
      File.write!(Path.join(releases, "#{name}.boot"), :erlang.term_to_binary(script))
    end

    applications =
      Map.new(apps, fn {app, vsn, modules} ->
        {app, [vsn: vsn, modules: modules, path: "/somewhere/#{app}", otp_app?: false]}
      end)

    %Mix.Release{name: :test, version: "0.1.0", path: release_path, applications: applications}
  end

  defp write_term(path, term) do
    File.write!(path, :unicode.characters_to_binary(:io_lib.format("~tp.~n", [term])))
  end

  defp beams(release, app_dir) do
    Path.wildcard("#{release.path}/lib/#{app_dir}/ebin/*.beam")
    |> Enum.map(&Path.basename/1)
    |> Enum.sort()
  end

  defp read_app(release, app_dir) do
    [path] = Path.wildcard("#{release.path}/lib/#{app_dir}/ebin/*.app")
    {:ok, [term]} = :file.consult(path)
    term
  end

  defp read_boot(release, name) do
    Path.join(release.path, "releases/0.1.0/#{name}.boot")
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  defp read_script(release, name) do
    {:ok, [term]} = :file.consult(Path.join(release.path, "releases/0.1.0/#{name}.script"))
    term
  end

  defp prim_loaded({:script, _, instructions}) do
    Enum.flat_map(instructions, fn
      {:primLoad, modules} -> modules
      _ -> []
    end)
  end

  defp loaded_app_modules({:script, _, instructions}, app) do
    Enum.find_value(instructions, fn
      {:apply, {:application, :load, [{:application, ^app, properties}]}} -> properties[:modules]
      _ -> nil
    end)
  end

  defp snapshot(release) do
    Path.wildcard("#{release.path}/**")
    |> Enum.reject(&File.dir?/1)
    |> Map.new(&{&1, File.read!(&1)})
  end
end
