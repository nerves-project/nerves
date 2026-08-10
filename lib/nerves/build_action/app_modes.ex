# SPDX-FileCopyrightText: 2019 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.AppModes do
  @moduledoc """
  Change most OTP application modes from `:permanent` to avoid reboot on crash

  This is a pre-assemble release step. When an application started as
  `:permanent` exits, it takes down the entire Erlang VM. For Nerves
  devices, this is usually undesirable — you want the system to remain
  running so that error-recovery logic or remote debugging can kick in.
  In general, using alarms like with the Alarmist library and Erlang heart
  has been found to be easier for developing, recovering and maintaining
  Nerves devices.

  This step changes all `:permanent` applications to `:temporary`, except
  for a core set that must remain `:permanent` for the VM to function:

    * `:kernel`, `:stdlib`, `:compiler`, `:elixir`, `:iex`
    * `:crypto`, `:logger`, `:sasl`, `:runtime_tools`

  Other modes (`:transient`, `:temporary`, `:load`, `:none`) are left
  unchanged.
  """

  use Nerves.BuildAction

  # These applications are essential and stay permanent
  @permanent_applications [
    :runtime_tools,
    :kernel,
    :stdlib,
    :compiler,
    :elixir,
    :iex,
    :crypto,
    :logger,
    :sasl
  ]

  @doc """
  Update application modes in the `:start` boot script.

  Changes `:permanent` to `:temporary` for all applications not in the
  core permanent set.

  On host builds, returns the release unchanged.
  """
  @impl Nerves.BuildAction
  def pre_assemble_steps(%Nerves.BuildPlan{} = _build_plan, %Mix.Release{} = release, _opts) do
    case release.boot_scripts[:start] do
      nil ->
        # No start script yet — build modes from applications map
        app_modes =
          release.applications
          |> Enum.map(fn {app, _info} -> {app, :permanent} end)
          |> Enum.map(&maybe_make_temporary/1)

        new_boot_scripts = Map.put(release.boot_scripts, :start, app_modes)
        %{release | boot_scripts: new_boot_scripts}

      app_modes ->
        updated = Enum.map(app_modes, &maybe_make_temporary/1)
        new_boot_scripts = Map.put(release.boot_scripts, :start, updated)
        %{release | boot_scripts: new_boot_scripts}
    end
  end

  defp maybe_make_temporary({app, :permanent}) do
    if app in @permanent_applications do
      {app, :permanent}
    else
      {app, :temporary}
    end
  end

  defp maybe_make_temporary({app, mode}), do: {app, mode}
end
