Mix.shell(Mix.Shell.Process)

defmodule MixHelper do
  import ExUnit.Assertions
  # Much <3 to Phoenix for this code
  def tmp_path do
    Path.expand("../../tmp", __DIR__)
  end

  def in_tmp(which, function) do
    path = Path.join(tmp_path(), to_string(which))
    File.rm_rf! path
    File.mkdir_p! path
    File.cd! path, function
  end

  def assert_file(file) do
    assert File.regular?(file), "Expected #{file} to exist, but does not"
  end

  def refute_file(file) do
    refute File.regular?(file), "Expected #{file} to not exist, but it does"
  end

  def assert_file(file, match) do
    cond do
      is_list(match) ->
        assert_file file, &(Enum.each(match, fn(m) -> assert &1 =~ m end))
      is_binary(match) or Regex.regex?(match) ->
        assert_file file, &(assert &1 =~ match)
      is_function(match, 1) ->
        assert_file(file)
        match.(File.read!(file))
      true -> raise inspect({file, match})
    end
  end
end
