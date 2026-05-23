# SPDX-FileCopyrightText: None
#
# SPDX-License-Identifier: CC0-1.0
#
defmodule SimpleApp.Fixture do
  use Mix.Project

  def project() do
    [
      app: :simple_app,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 1.15"],
      deps: deps()
    ]
  end

  def application() do
    [applications: []]
  end

  defp deps() do
    [
      {:system, path: "../system"}
    ]
  end
end
