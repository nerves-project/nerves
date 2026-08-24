defmodule CoverHelper do
  @moduledoc false

  @doc """
  Helper to run mix with code coverage if coverage is being tracked
  """
  def mix(["deps.get" | _] = args, opts) do
    # Exporting coverage when getting dependencies doesn't work, so short circuit
    # it to just run the command.
    run_mix(args, opts)
  end

  def mix(args, opts) do
    final_args =
      if :cover.modules() != [],
        do: ["cover", File.cwd!(), cover_export_name(args, opts)] ++ args,
        else: args

    run_mix(final_args, opts)
  end

  defp run_mix(args, opts) do
    final_opts = Keyword.merge([stderr_to_stdout: true, into: IO.stream()], opts)
    System.cmd("mix", args, final_opts)
  end

  defp cover_export_name([task | _], opts) do
    path = Path.basename(opts[:cd] || File.cwd!())

    "#{path}_#{target(opts)}_#{task}"
  end

  defp target(opts) do
    env = Keyword.get(opts, :env, [])
    Enum.find_value(env, "host", fn {k, v} -> if k == "MIX_TARGET", do: v end)
  end
end
