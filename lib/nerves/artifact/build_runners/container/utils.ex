# SPDX-FileCopyrightText: 2026 Thomas Winkler
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.BuildRunners.Container.Utils do
  @moduledoc false

  @doc false
  @spec shell_info(String.t(), String.t()) :: :ok
  def shell_info(header, text \\ "") do
    Mix.Nerves.IO.shell_info(header, text, Container)
  end
end
