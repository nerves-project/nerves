defmodule Nerves.Package.Provider do
  @callback artifact(package :: Nerves.Package.t, toolchain :: atom) ::
    :ok | {:error, error :: term}

  defmacro __using__(_opts) do
    quote do
      @behaviour Nerves.Package.Provider
    end
  end

  def artifact(_, nil) do
    Mix.raise "Nerves was unable to locate your toolchain."
  end

  def artifact(%{type: :toolchain} = pkg, toolchain) do
    mod =
      case :os.type do
        {_, :linux} -> provider("http")
        {_, :darwin} -> provider("http")
        _ -> provider("local")
      end
    mod.artifact(toolchain, toolchain)
  end
  def artifact(pkg, toolchain) do
    Application.ensure_started(pkg.app)

    Application.get_env(pkg.app, :nerves_env)
    |> IO.inspect
    mod = default
    mod.artifact(pkg, toolchain)
  end

  defp provider(nil), do: default()
  defp provider("http"), do: Nerves.Package.Providers.HTTP
  defp provider("local"), do: Nerves.Package.Providers.Local
  defp provider("docker"), do:  Nerves.Package.Providers.Docker
  defp provider(provider), do:  provider

  defp default do
    case :os.type do
      {_, :linux} -> provider("local")
      _ -> provider("docker")
    end
  end

end
