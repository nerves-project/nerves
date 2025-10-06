# SPDX-FileCopyrightText: 2018 Frank Hunleth
# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Nerves.Shell do
  @moduledoc false
  alias Mix.Nerves.Utils

  @doc """
  Open a shell with the Nerves environment set

  Used with build runners when compiling Nerves systems
  """
  @spec open(String.t()) :: :ok
  def open(command) do
    env = %{
      "PATH" => Utils.sanitize_path(),
      # Unset these Env vars which are set by the host Erlang
      # and might interfere with the build
      "BINDIR" => nil,
      "MIX_HOME" => nil,
      "PROGNAME" => nil,
      "ROOTDIR" => nil
    }

    Utils.interactive_shell(command, [], env: env)
  end
end
