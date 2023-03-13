defmodule Nerves.IntegrationTest do
  use NervesTest.Case, async: true

  @tag :tmp_dir
  @tag :integration
  test "bootstrap is called for other env packages", %{tmp_dir: tmp} do
    deps = ~w(system toolchain system_platform toolchain_platform host_tool)

    {path, _env} = compile_fixture!("integration_app", tmp, deps)

    file = Path.join(path, "hello")

    assert File.exists?(file)
    assert File.read!(file) == "Hello, world!\n"
  end
end
