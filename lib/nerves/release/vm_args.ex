defmodule Nerves.Release.VmArgs do
  @moduledoc false

  @elixir_1_15_opts ["-user elixir", "-run elixir start_iex"]
  @elixir_1_17_opts ["-user elixir", "-run elixir start_cli"]
  @legacy_elixir_opts ["-user Elixir.IEx.CLI"]

  @spec check_compatibility!(Mix.Release.t()) :: Mix.Release.t()
  def check_compatibility!(release) do
    Mix.shell().info([:yellow, "* [Nerves] ", :reset, "validating vm.args"])
    vm_args_path = Mix.Release.rel_templates_path(release, "vm.args.eex")

    if not File.exists?(vm_args_path) do
      Mix.raise("Missing required #{vm_args_path}")
    end

    {exclusions, inclusions} =
      cond do
        Version.match?(System.version(), ">= 1.17.0") ->
          {["-run elixir start_iex" | @legacy_elixir_opts], @elixir_1_17_opts}

        Version.match?(System.version(), ">= 1.15.0") ->
          {["-run elixir start_cli" | @legacy_elixir_opts], @elixir_1_15_opts}

        true ->
          exclude = Enum.uniq(@elixir_1_15_opts ++ @elixir_1_17_opts)
          {exclude, @legacy_elixir_opts}
      end

    vm_args = File.read!(vm_args_path)

    errors =
      []
      |> check_vm_args_inclusions(vm_args, inclusions, vm_args_path)
      |> check_vm_args_exclusions(vm_args, exclusions, vm_args_path)

    if length(errors) > 0 do
      errs = IO.ANSI.format(errors) |> IO.chardata_to_string()

      Mix.raise("""
      Incompatible vm.args.eex

      The procedure for starting IEx changed in newer Elixir versions. The
      rel/vm.args.eex for this project starts IEx in an incompatible way for
      the version of Elixir you're using and won't work.

      To fix this, either change the version of Elixir that you're using or make the
      following changes to vm.args.eex:
      #{errs}
      """)
    end

    release
  end

  defp check_vm_args_exclusions(errors, vm_args, exclusions, vm_args_path) do
    String.split(vm_args, "\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> Enum.any?(exclusions, &String.contains?(line, &1)) end)
    |> case do
      [] ->
        []

      lines ->
        [
          "\nPlease remove the following lines:\n\n",
          Enum.map(lines, fn {line, line_num} ->
            ["* ", vm_args_path, ":", to_string(line_num), ":\n  ", :red, line, "\n"]
          end)
          | errors
        ]
    end
  end

  defp check_vm_args_inclusions(errors, vm_args, inclusions, vm_args_path) do
    case Enum.reject(inclusions, &String.contains?(vm_args, &1)) do
      [] ->
        []

      lines ->
        [
          [
            "\nPlease ensure the following lines are in ",
            vm_args_path,
            ":\n",
            :green,
            Enum.map(lines, &["  ", &1, "\n"])
          ]
          | errors
        ]
    end
  end
end
