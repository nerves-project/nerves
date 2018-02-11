defmodule Nerves.IntegrationTest do
  use NervesTest.Case, async: false

  @tag :integration
  test "bootstrap is called for other env packages" do
    in_fixture("integration_app", fn ->
      packages = ~w(system toolchain system_platform toolchain_platform host_tool)

      load_env(packages)
      Mix.Tasks.Deps.Get.run([])
      Mix.Tasks.Nerves.Env.run([])
      Mix.Tasks.Nerves.Precompile.run([])
      Mix.Tasks.Compile.run([])

      file =
        File.cwd!()
        |> Path.join("hello")

      assert File.exists?(file)
      assert File.read!(file) == "Hello, world!\n"
    end)
  end
end
