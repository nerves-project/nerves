defmodule Nerves.Artifact.Providers.Docker.Utils do

  def shell_info(header, text \\ "") do
    Mix.Nerves.IO.shell_info(header, text, Docker)
  end

end
