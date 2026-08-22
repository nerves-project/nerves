defmodule CoverHelper do
  @moduledoc false

  @doc """
  Helper to run mix with code coverage if coverage is being tracked

  * `:cover_export` - filename for coverage to be exported to (not a path)
  """
  def mix(args, opts) do
    {cover_export, cmd_opts} = Keyword.pop(opts, :cover_export)

    final_args =
      if cover_export != nil and :cover.modules() != [],
        do: ["cover", File.cwd!(), cover_export] ++ args,
        else: args

    final_opts = Keyword.merge([stderr_to_stdout: true, into: IO.stream()], cmd_opts)
    System.cmd("mix", final_args, final_opts)
  end
end
