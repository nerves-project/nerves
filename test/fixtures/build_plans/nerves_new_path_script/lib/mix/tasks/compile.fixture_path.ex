defmodule Mix.Tasks.Compile.FixturePath do
  use Mix.Task.Compiler

  @recursive true

  @impl Mix.Task.Compiler
  def run(_args) do
    output_path = Path.join([Mix.Project.app_path(), "priv", "compile_output.txt"])
    File.mkdir_p!(Path.dirname(output_path))

    case System.cmd("custom-host-tool", [], stderr_to_stdout: true) do
      {output, 0} ->
        File.write!(output_path, output)
        {:ok, []}

      {output, status} ->
        Mix.raise("custom-host-tool failed with status #{status}:\n\n#{output}")
    end
  end

  @impl Mix.Task.Compiler
  def clean() do
    _ = File.rm_rf(Path.join([Mix.Project.app_path(), "priv"]))
    :ok
  end
end
