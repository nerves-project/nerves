defmodule Nerves.Precompiled.Config do
  @moduledoc false

  @type t :: %{source: String.t(), except: [atom()], root_path: Path.t(), home: Path.t()}

  @spec load() :: t() | nil
  def load() do
    opts = Application.get_env(:nerves, :precompiled, [])

    with false <- System.get_env("NERVES_PRECOMPILED") in ["0", "false", "no"],
         source when is_binary(source) <- opts[:source] do
      %{
        source: String.trim_trailing(source, "/"),
        except: except(opts[:except]),
        root_path: opts[:root] || Path.join(:code.priv_dir(:nerves), "precompiled/root.json"),
        home: System.get_env("NERVES_PRECOMPILED_HOME") || Path.expand("~/.nerves/precompiled")
      }
    else
      _ -> nil
    end
  end

  defp except(list) when is_list(list) do
    {good, bad} = Enum.split_with(list, &(is_atom(&1) or is_binary(&1)))

    if bad != [] do
      Nerves.MixUtils.warning(
        "precompiled: ignoring except entries that are not dependency names: #{inspect(bad)}"
      )
    end

    Enum.map(good, &to_atom/1)
  end

  defp except(nil), do: []

  defp except(other) do
    Nerves.MixUtils.warning("precompiled: ignoring except, not a list: #{inspect(other)}")
    []
  end

  defp to_atom(a) when is_atom(a), do: a
  defp to_atom(s) when is_binary(s), do: String.to_atom(s)
end
