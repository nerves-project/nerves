defmodule Package.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.trim

  def project do
    [app: :package,
     version: @version,
     compilers: Mix.compilers ++ [:nerves_package],
     deps: deps()]
  end

  defp deps do
     [{:system_platform, path: "../system_platform"}]
  end
end
