defmodule <%= application_module %>.Mixfile do
  use Mix.Project

  @target System.get_env("NERVES_TARGET") || "<%= default_target %>"

  def project do
    [app: :<%= application_name %>,
     version: "0.1.0",
     target: @target,
     archives: [nerves_bootstrap: "~> <%= bootstrap_vsn %>"],
     <%= if in_umbrella do %>
     deps_path: "../../deps/#{@target}",
     build_path: "../../_build/#{@target}",
     config_path: "../../config/config.exs",
     lockfile: "../../mix.lock",
     <% else %>
     deps_path: "deps/#{@target}",
     build_path: "_build/#{@target}",
     <% end %>
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps() ++ system(@target)]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {<%= application_module %>, []},
     applications: [:logger]]
  end

  def deps do
    [<%= nerves_dep %>]
  end

  def system(target) do
    [{:"nerves_system_#{target}", ">= 0.0.0"}]
  end

  def aliases do
    ["deps.precompile": ["nerves.precompile", "deps.precompile"],
     "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]]
  end

end
