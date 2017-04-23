defmodule SystemV1.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.trim

  def project do
    [app: :system_v1,
     version: @version,
     deps: deps()]
  end

  defp deps do
    [{:toolchain_v1, path: "../toolchain_v1"}]
  end
end
