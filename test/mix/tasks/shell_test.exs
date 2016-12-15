defmodule Nerves.Mix.Tasks.ShellTest do
  use NervesTest.Case, async: false

  setup do
    %{fixture: "simple_app"}
  end

  # test "Start a package shell", %{fixture: app} do
  #   in_fixture app, fn ->
  #     ~w(system toolchain system_platform toolchain_platform)
  #     |> load_env()
  #
  #     Mix.Tasks.Nerves.Shell.run(["pkg", "system"])
  #   end
  # end

  test "Error starting shell for non package", %{fixture: app} do
    in_fixture app, fn ->
      load_env()
      assert_raise Mix.Error, ~r/Package is not loaded in your Nerves Environment/, fn ->
        Mix.Tasks.Nerves.Shell.run(["pkg", "not_a_pkg"])
      end
    end
  end

end
