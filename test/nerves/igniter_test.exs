# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.IgniterTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  doctest Nerves.Igniter

  defp mix_exs(deps, attributes) do
    """
    defmodule Test.MixProject do
      use Mix.Project
    #{attributes}
      def project do
        [
          app: :test,
          version: "0.1.0",
          deps: deps()
        ]
      end

      defp deps do
        #{deps}
      end
    end
    """
  end

  defp project(deps, attributes \\ "") do
    test_project(files: %{"mix.exs" => mix_exs(deps, attributes)})
  end

  defp content(igniter, path) do
    igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
  end

  describe "official_systems/0" do
    test "has a system and a valid requirement for every target" do
      for {target, {system_app, requirement}} <- Nerves.Igniter.official_systems() do
        assert is_atom(target)
        assert String.starts_with?(Atom.to_string(system_app), "nerves_system_")
        assert {:ok, _} = Version.parse_requirement(requirement)
      end
    end

    test "includes all of the default targets" do
      official = Nerves.Igniter.official_systems()

      assert Enum.all?(Nerves.Igniter.default_targets(), &Map.has_key?(official, &1))
    end
  end

  describe "add_system/4" do
    test "adds an official system with its default requirement" do
      project("[]")
      |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)
      |> assert_has_patch("mix.exs", """
      + |    [{:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}]
      """)
    end

    test "appends to the dependencies" do
      igniter =
        project(~s|[{:nerves, "~> 2.0", runtime: false}]|)
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)
        |> Nerves.Igniter.add_system(:nerves_system_bbb, :bbb)

      assert content(igniter, "mix.exs") =~ """
                 [
                   {:nerves, "~> 2.0", runtime: false},
                   {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4},
                   {:nerves_system_bbb, "~> 2.19", runtime: false, targets: :bbb}
                 ]
             """
    end

    test "uses the :requirement option" do
      igniter =
        project("[]")
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4, requirement: "~> 2.1")
        |> Nerves.Igniter.add_system(:my_system, :my_board, requirement: "~> 0.1")

      assert content(igniter, "mix.exs") =~
               ~s|{:nerves_system_rpi4, "~> 2.1", runtime: false, targets: :rpi4}|

      assert content(igniter, "mix.exs") =~
               ~s|{:my_system, "~> 0.1", runtime: false, targets: :my_board}|
    end

    test "uses the :source option" do
      igniter =
        Nerves.Igniter.add_system(project("[]"), :my_system, :my_board,
          source: [path: "../my_system"]
        )

      assert content(igniter, "mix.exs") =~
               ~s|{:my_system, path: "../my_system", runtime: false, targets: :my_board}|
    end

    test "uses :requirement and :source together" do
      igniter =
        Nerves.Igniter.add_system(project("[]"), :my_system, :my_board,
          requirement: "~> 1.0",
          source: [organization: "acme"]
        )

      assert content(igniter, "mix.exs") =~
               ~s|{:my_system, "~> 1.0", organization: "acme", runtime: false, targets: :my_board}|
    end

    test "raises when an unofficial system doesn't have a requirement" do
      assert_raise ArgumentError, ~r/:requirement option is required/, fn ->
        Nerves.Igniter.add_system(project("[]"), :my_system, :my_board)
      end

      assert_raise ArgumentError, ~r/version requirement string/, fn ->
        Nerves.Igniter.add_system(project("[]"), :my_system, :my_board, requirement: 1)
      end
    end

    test "is idempotent" do
      project("[]")
      |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)
      |> apply_igniter!()
      |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)
      |> assert_unchanged()
    end

    test "fixes up the bare dependency that `mix igniter.install` adds" do
      igniter =
        project(~s|[{:nerves_system_rpi4, "~> 2.0.1"}]|)
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)

      assert content(igniter, "mix.exs") =~
               ~s|[{:nerves_system_rpi4, "~> 2.0.1", runtime: false, targets: :rpi4}]|
    end

    test "keeps the source of an existing dependency" do
      igniter =
        project(~s|[{:nerves_system_rpi4, path: "../nerves_system_rpi4", runtime: true}]|)
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4, requirement: "~> 9.0")

      assert content(igniter, "mix.exs") =~
               ~s|[{:nerves_system_rpi4, path: "../nerves_system_rpi4", runtime: false, targets: :rpi4}]|
    end

    test "adds the target to an existing dependency's targets" do
      igniter =
        project("""
        [
          {:my_system, "~> 1.0", runtime: false, targets: :board_a},
          {:other_system, "~> 1.0", runtime: false, targets: [:board_a, :board_b]},
          {:computed_system, "~> 1.0", runtime: false, targets: @all_targets}
        ]
        """)
        |> Nerves.Igniter.add_system(:my_system, :board_c)
        |> Nerves.Igniter.add_system(:other_system, :board_c)
        |> Nerves.Igniter.add_system(:other_system, :board_b)
        |> Nerves.Igniter.add_system(:computed_system, :board_c)

      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~ ~s|{:my_system, "~> 1.0", runtime: false, targets: [:board_a, :board_c]}|

      assert mix_exs =~
               ~s|{:other_system, "~> 1.0", runtime: false, targets: [:board_a, :board_b, :board_c]}|

      assert mix_exs =~ ~s|{:computed_system, "~> 1.0", runtime: false, targets: @all_targets}|
    end

    test "keeps @all_targets in sync" do
      deps = ~s|[{:nerves_pack, "~> 0.7", targets: @all_targets}]|

      igniter =
        project(deps, "  @all_targets [:rpi0, :bbb]\n")
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)
        |> Nerves.Igniter.add_system(:nerves_system_bbb, :bbb)

      assert content(igniter, "mix.exs") =~ "@all_targets [:rpi0, :bbb, :rpi4]\n"

      igniter
      |> apply_igniter!()
      |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)
      |> assert_unchanged()
    end

    test "leaves an @all_targets that isn't a list alone" do
      igniter =
        project("[]", "  @all_targets Application.compile_env(:test, :targets, [])\n")
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)

      assert content(igniter, "mix.exs") =~
               "@all_targets Application.compile_env(:test, :targets, [])\n"
    end
  end

  describe "@all_targets" do
    test "add_system/4 creates it when it's missing" do
      igniter = Nerves.Igniter.add_system(project("[]"), :nerves_system_rpi4, :rpi4)

      assert content(igniter, "mix.exs") == """
             defmodule Test.MixProject do
               use Mix.Project

               @all_targets [:rpi4]

               def project do
                 [
                   app: :test,
                   version: "0.1.0",
                   deps: deps(),
                   nerves_targets: @all_targets
                 ]
               end

               defp deps do
                 [{:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}]
               end
             end
             """
    end

    test "add_system/4 extends the one that it created" do
      igniter =
        project("[]")
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)
        |> Nerves.Igniter.add_system(:nerves_system_rpi0, :rpi0)
        |> apply_igniter!()
        |> Nerves.Igniter.add_system(:my_system, :my_board, requirement: "~> 1.0")

      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~ "  @all_targets [:rpi4, :rpi0, :my_board]\n"
      # One definition and one use
      assert length(String.split(mix_exs, "@all_targets")) == 3

      igniter
      |> apply_igniter!()
      |> Nerves.Igniter.add_system(:nerves_system_rpi0, :rpi0)
      |> Nerves.Igniter.add_system(:my_system, :my_board, requirement: "~> 1.0")
      |> Nerves.Igniter.ensure_all_targets()
      |> assert_unchanged()
    end

    test "add_system/4 includes the targets of the systems that are already there" do
      igniter =
        project("""
        [
          {:nerves_system_rpi0, "~> 2.0", runtime: false, targets: :rpi0},
          {:nerves_system_custom, path: "../custom", runtime: false, targets: [:a, :b]}
        ]
        """)
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)

      assert content(igniter, "mix.exs") =~ "  @all_targets [:rpi0, :a, :b, :rpi4]\n"
    end

    test "is put next to other module attributes" do
      igniter =
        project("[]", "\n  @app :test\n  @version \"0.1.0\"\n")
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)

      assert content(igniter, "mix.exs") =~
               "  @app :test\n  @version \"0.1.0\"\n  @all_targets [:rpi4]\n\n  def project do\n"
    end

    test "isn't referenced from project/0 when a dependency refers to it" do
      # The attribute went missing, but it's still used
      igniter =
        project(~s|[{:vintage_net, "~> 0.13", targets: @all_targets}]|)
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)

      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~ "  @all_targets [:rpi4]\n"
      refute mix_exs =~ "nerves_targets"
    end

    test "keeps a project/0 option of the same name" do
      mix_exs =
        String.replace(
          mix_exs("[]", ""),
          "deps: deps()",
          "deps: deps(),\n      nerves_targets: [:mine]"
        )

      igniter =
        test_project(files: %{"mix.exs" => mix_exs})
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)

      assert content(igniter, "mix.exs") =~ "nerves_targets: [:mine]\n"
    end

    test "ensure_all_targets/1 creates it from the project's systems" do
      deps = """
      [
        {:nerves_system_rpi0, "~> 2.0", runtime: false, targets: :rpi0},
        {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}
      ]
      """

      igniter = Nerves.Igniter.ensure_all_targets(project(deps))
      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~ "  @all_targets [:rpi0, :rpi4]\n\n  def project do\n"
      assert mix_exs =~ "      nerves_targets: @all_targets\n"

      igniter |> apply_igniter!() |> Nerves.Igniter.ensure_all_targets() |> assert_unchanged()
    end

    test "ensure_all_targets/1 does nothing without systems" do
      project("[]") |> Nerves.Igniter.ensure_all_targets() |> assert_unchanged()
    end

    test "ensure_all_targets/1 keeps an existing attribute" do
      deps = """
      [
        {:nerves_pack, "~> 0.7", targets: @all_targets},
        {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}
      ]
      """

      for value <- ["[:rpi0]", "[]", "Application.compile_env(:test, :targets, [])"] do
        project(deps, "  @all_targets #{value}\n")
        |> Nerves.Igniter.ensure_all_targets()
        |> assert_unchanged()
      end
    end

    test "warns when there's no project/0 to put it above" do
      mix_exs = """
      defmodule Test.MixProject do
        use Mix.Project

        def project(), do: Keyword.merge(base(), deps: [])
        defp base(), do: [app: :test, version: "0.1.0"]
      end
      """

      igniter =
        test_project(
          files: %{"mix.exs" => String.replace(mix_exs, "def project()", "def  project()")}
        )
        |> Nerves.Igniter.add_system(:nerves_system_rpi4, :rpi4)

      refute content(igniter, "mix.exs") =~ "@all_targets"
      assert Enum.any?(igniter.warnings, &(&1 =~ "could not add `@all_targets [:rpi4]`"))
    end
  end

  describe "add_target/2" do
    test "adds the official system for the target" do
      igniter = Nerves.Igniter.add_target(project("[]"), :x86_64)

      assert content(igniter, "mix.exs") =~
               ~s|{:nerves_system_x86_64, "~> 1.24", runtime: false, targets: :x86_64}|
    end

    test "adds an issue for unknown targets" do
      project("[]")
      |> Nerves.Igniter.add_target(:my_board)
      |> assert_has_issue(&(&1 =~ "Unknown Nerves target :my_board"))
    end
  end

  describe "project_targets/1" do
    test "returns the targets of the Nerves systems in listed order" do
      igniter =
        project("""
        [
          {:nerves, "~> 2.0", runtime: false},
          {:nerves_pack, "~> 0.7", targets: [:not_a_system]},
          {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4},
          {:nerves_system_custom, path: "../custom", runtime: false, targets: [:a, :b]},
          {:nerves_system_computed, "~> 1.0", runtime: false, targets: @all_targets},
          {:nerves_system_rpi0, "~> 2.0", runtime: false, targets: :rpi0}
        ]
        """)

      assert Nerves.Igniter.project_targets(igniter) == [:rpi4, :a, :b, :rpi0]
    end

    test "returns an empty list for projects without systems" do
      assert Nerves.Igniter.project_targets(test_project()) == []
    end

    test "sees systems that were added" do
      igniter = Nerves.Igniter.add_target(test_project(), :rpi5)

      assert Nerves.Igniter.project_targets(igniter) == [:rpi5]
    end
  end

  describe "project predicates" do
    test "plain projects aren't Nerves projects" do
      igniter = test_project()

      refute Nerves.Igniter.nerves_project?(igniter)
      assert Nerves.Igniter.device_config_file(igniter) == "config.exs"
      assert Nerves.Igniter.host_config_file(igniter) == nil
    end

    test "projects that depend on nerves are Nerves projects" do
      igniter = project(~s|[{:nerves, "~> 2.0", runtime: false}]|)

      assert Nerves.Igniter.nerves_project?(igniter)
      assert Nerves.Igniter.device_config_file(igniter) == "config.exs"
    end

    test "projects with a config/target.exs are Nerves projects" do
      igniter =
        test_project(
          files: %{
            "config/target.exs" => "import Config\n",
            "config/host.exs" => "import Config\n"
          }
        )

      assert Nerves.Igniter.nerves_project?(igniter)
      assert Nerves.Igniter.device_config_file(igniter) == "target.exs"
      assert Nerves.Igniter.host_config_file(igniter) == "host.exs"
    end

    test "see files that were created by other installers" do
      igniter = Igniter.create_new_file(test_project(), "config/target.exs", "import Config\n")

      assert Nerves.Igniter.device_config_file(igniter) == "target.exs"
    end
  end
end
