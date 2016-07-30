defmodule Toolchain.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.strip

  def project do
    [app: :toolchain,
     version: @version,
     compilers: Mix.compilers ++ [:nerves_package],
     deps: deps()]
  end

  defp deps do
    [{:nerves, path: "../../../"},
     {:toolchain_platform, path: "../toolchain_platform"}]
  end
end
