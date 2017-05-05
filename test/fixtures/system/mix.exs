defmodule System.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.trim

  def project do
    [app: :system,
     version: @version,
     compilers: Mix.compilers ++ [:nerves_package],
     deps: deps()]
  end

  defp deps do
    [{:nerves, path: "../../../"},
     {:toolchain, path: "../toolchain"},
     {:system_platform, path: "../system_platform"}]
  end
end
