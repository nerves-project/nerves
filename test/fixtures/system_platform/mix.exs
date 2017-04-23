defmodule SystemPlatform.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.trim

  def project do
    [app: :system_platform,
     version: @version,
     deps: deps()]
  end

  defp deps do
    []
  end
end
