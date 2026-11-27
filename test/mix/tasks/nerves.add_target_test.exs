# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.AddTargetTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  @mix_exs """
  defmodule Test.MixProject do
    use Mix.Project

    @all_targets [:rpi4]

    def project do
      [
        app: :test,
        version: "0.1.0",
        deps: deps()
      ]
    end

    defp deps do
      [
        {:nerves, "~> 1.0", runtime: false},
        {:nerves_pack, "~> 0.7", targets: @all_targets},
        {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}
      ]
    end
  end
  """

  defp nerves_project() do
    test_project(files: %{"mix.exs" => @mix_exs, "config/target.exs" => "import Config\n"})
  end

  defp add_target(igniter, argv) do
    Igniter.compose_task(igniter, "nerves.add_target", argv)
  end

  defp content(igniter, path) do
    igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
  end

  test "adds the system and extends @all_targets" do
    igniter = add_target(nerves_project(), ["rpi5"])

    assert igniter.issues == []
    mix_exs = content(igniter, "mix.exs")
    assert mix_exs =~ ~s|{:nerves_system_rpi5, "~> 2.0", runtime: false, targets: :rpi5}|
    assert mix_exs =~ "@all_targets [:rpi4, :rpi5]"
    assert Nerves.Igniter.project_targets(igniter) == [:rpi4, :rpi5]
  end

  test "only changes mix.exs" do
    nerves_project()
    |> add_target(["rpi5"])
    |> assert_unchanged("config/target.exs")
  end

  test "adds more than one target" do
    igniter = add_target(nerves_project(), ["rpi5", "rpi0_2,bbb"])

    assert igniter.issues == []
    assert Nerves.Igniter.project_targets(igniter) == [:rpi4, :rpi5, :rpi0_2, :bbb]
  end

  test "doesn't change a project that has the target" do
    nerves_project()
    |> add_target(["rpi4"])
    |> assert_unchanged("mix.exs")
  end

  test "is idempotent" do
    nerves_project()
    |> add_target(["rpi5"])
    |> apply_igniter!()
    |> add_target(["rpi5"])
    |> assert_unchanged("mix.exs")
  end

  test "fails on unknown targets without changing anything" do
    igniter = add_target(nerves_project(), ["rpi5", "my_board"])

    assert [issue] = igniter.issues
    assert issue =~ "my_board"
    assert {:error, _} = apply_igniter(igniter)
  end

  test "fails when no target is given" do
    assert_raise ArgumentError, ~r/one or more values for positional argument `targets`/, fn ->
      add_target(nerves_project(), [])
    end
  end

  test "points projects that aren't Nerves projects to the installer" do
    igniter = add_target(test_project(), ["rpi4"])

    assert [issue] = igniter.issues
    assert issue =~ "mix igniter.install nerves"
  end

  describe "systems that aren't official" do
    test "adds a system from GitHub for the named target" do
      igniter =
        add_target(nerves_project(), [
          "my_board",
          "nerves_system_whatever@github:lawik/nerves_system_whatever"
        ])

      assert igniter.issues == []
      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~ "{:nerves_system_whatever,\n"

      assert mix_exs =~
               ~s|github: "lawik/nerves_system_whatever", runtime: false, targets: :my_board}|

      assert mix_exs =~ "@all_targets [:rpi4, :my_board]"
    end

    test "keeps the Git ref" do
      igniter =
        add_target(nerves_project(), [
          "my_board",
          "nerves_system_whatever@github:lawik/nerves_system_whatever@v1.2.0"
        ])

      assert content(igniter, "mix.exs") =~
               ~s|github: "lawik/nerves_system_whatever", ref: "v1.2.0", runtime: false, targets: :my_board}|
    end

    test "adds a system from a Git URL" do
      igniter =
        add_target(nerves_project(), [
          "my_board",
          "custom_system@git:https://example.com/custom_system.git"
        ])

      mix_exs = content(igniter, "mix.exs")
      assert mix_exs =~ "{:custom_system,\n"

      assert mix_exs =~
               ~s|git: "https://example.com/custom_system.git", runtime: false, targets: :my_board}|
    end

    test "adds a system from a path" do
      igniter =
        add_target(nerves_project(), ["my_board", "custom_system@path:../custom_system"])

      assert content(igniter, "mix.exs") =~
               ~s|{:custom_system, path: "../custom_system", runtime: false, targets: :my_board}|
    end

    test "adds a system from Hex with a version" do
      igniter = add_target(nerves_project(), ["my_board", "custom_system@1.2.3"])

      assert content(igniter, "mix.exs") =~
               ~s|{:custom_system, "== 1.2.3", runtime: false, targets: :my_board}|
    end

    test "gets the target from the package name when it's left out" do
      igniter =
        add_target(nerves_project(), ["nerves_system_whatever@path:../nerves_system_whatever"])

      assert igniter.issues == []
      assert Nerves.Igniter.project_targets(igniter) == [:rpi4, :whatever]
    end

    test "asks for the target when the package name doesn't have it" do
      igniter = add_target(nerves_project(), ["custom_system@path:../custom_system"])

      assert [issue] = igniter.issues
      assert issue =~ "mix nerves.add_target my_target custom_system@path:../custom_system"
    end

    test "can be mixed with official targets" do
      igniter =
        add_target(nerves_project(), [
          "rpi5",
          "my_board",
          "custom_system@path:../custom_system",
          "bbb"
        ])

      assert igniter.issues == []
      assert content(igniter, "mix.exs") =~ "@all_targets [:rpi4, :rpi5, :my_board, :bbb]"
    end

    test "points to the package syntax for unknown targets" do
      igniter = add_target(nerves_project(), ["my_board"])

      assert [issue] = igniter.issues
      assert issue =~ "mix nerves.add_target nerves_system_my_board@github:"
    end

    test "rejects target names that can't be Mix targets" do
      igniter = add_target(nerves_project(), ["My-Board", "custom_system@path:../custom_system"])

      assert [issue] = igniter.issues
      assert issue =~ "isn't a valid target name"
    end
  end
end
