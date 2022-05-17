defmodule Mix.Nerves.IO do
  @moduledoc false
  @app Mix.Project.config()[:app]

  @spec debug_info(String.t(), String.t(), atom()) :: :ok
  def debug_info(header, text \\ "", loc \\ @app) do
    if System.get_env("NERVES_DEBUG") == "1" do
      shell_info(header, text, loc)
    end

    :ok
  end

  @spec shell_info(String.t(), String.t(), atom()) :: :ok
  def shell_info(header, text \\ "", loc \\ @app) do
    Mix.shell().info([:inverse, "|#{loc}| #{header}", :reset])
    Mix.shell().info(text)
  end

  @spec shell_warn(String.t(), String.t(), atom()) :: :ok
  def shell_warn(header, text \\ "", loc \\ @app) do
    Mix.shell().error([:inverse, :red, "|#{loc}| #{header}", :reset])
    Mix.shell().error(text)
  end

  @spec nerves_env_info() :: :ok
  def nerves_env_info() do
    Mix.shell().info([
      :green,
      """

      Nerves environment
        MIX_TARGET:   #{Mix.target()}
        MIX_ENV:      #{Mix.env()}
      """,
      :reset
    ])
  end
end
