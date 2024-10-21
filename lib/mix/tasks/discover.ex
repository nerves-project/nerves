defmodule Mix.Tasks.Discover do
  @moduledoc """
  Find Nerves devices on the local network.

  Should find across wired network, wireless and even USB gadget mode.

  Currently using the MNDP library implementing the MicroTik Neighbor
  Discovery Protocol. This is more reliable than mDNS which often gets
  tangled up with general usage by the system.
  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    if Code.ensure_loaded?(MNDP) do
      Mix.Task.run("mndp.discover", args)
    else
      Mix.Nerves.IO.shell_warn("Discovery requires :mndp to be installed in your Nerves project.")
      Mix.Nerves.IO.shell_info("""
      You can add it to your dependencies with:

      {:mndp, "~> 0.1.2"}

      Re-build your firmware, update your device with it and then try again.
      """)
    end
  end
end
