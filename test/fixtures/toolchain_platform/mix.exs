defmodule ToolchainPlatform.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.strip

  def project do
    [app: :toolchain_platform,
     version: @version,
     deps: deps()]
  end

  defp deps do
    []
  end
end
