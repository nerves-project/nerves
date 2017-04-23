defmodule ToolchainV1.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.trim

  def project do
    [app: :toolchain_v1,
     version: @version,
     deps: deps()]
  end

  defp deps do
    []
  end
end
