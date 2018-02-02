defmodule Nerves.PlatformTest do
  use NervesTest.Case, async: false
  alias Nerves.{Env, Artifact}

  test "bootstrap is called for extra env packages" do
    in_fixture "extra_app", fn ->
      packages =
        ~w(system toolchain system_platform toolchain_platform extra)
      
      load_env(packages)
        
      build(Env.system())
      build(Env.toolchain())
      build(Env.package(:extra))

      Env.bootstrap

      assert String.equivalent?(System.get_env("NERVES_BOOTSTRAP_EXTRA"), "1")
    end
  end

  defp build(pkg, toolchain \\ nil) do
    toolchain = toolchain || Env.toolchain()
    Artifact.build(pkg, toolchain)
  end
end
