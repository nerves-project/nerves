# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.BuildRunners.Docker.Utils do
  @moduledoc false

  @doc false
  @spec shell_info(String.t(), String.t()) :: :ok
  def shell_info(header, text \\ "") do
    Mix.Nerves.IO.shell_info(header, text, Docker)
  end
end
