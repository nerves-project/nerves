# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.IExStartupCheckTest do
  use ExUnit.Case, async: true

  alias Nerves.BuildAction.IExStartupCheck

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    release = %Mix.Release{options: [rel_templates_path: tmp_dir]}
    {:ok, release: release, vm_args_path: Path.join(tmp_dir, "vm.args.eex")}
  end

  test "skips validation for an Erlang shell", %{release: release, vm_args_path: path} do
    File.write!(path, """
    -setcookie <%= @release.options[:cookie] %>
    +Bc
    -mode embedded
    -kernel shell_history enabled
    """)

    assert IExStartupCheck.pre_assemble_steps(nil, release, []) == release
  end

  test "skips validation for a custom Erlang user module", %{
    release: release,
    vm_args_path: path
  } do
    File.write!(path, "-user custom_user\n")

    assert IExStartupCheck.check_vm_args!(release) == :ok
  end

  test "accepts compatible IEx startup flags", %{release: release, vm_args_path: path} do
    File.write!(path, "-user elixir\n-run elixir start_cli\n")

    assert IExStartupCheck.check_vm_args!(release) == :ok
  end

  for flag <- [
        "-user elixir",
        "-run elixir start_cli",
        "-run elixir start_iex",
        "-user Elixir.IEx.CLI"
      ] do
    test "validates an incomplete or obsolete IEx configuration containing #{flag}", %{
      release: release,
      vm_args_path: path
    } do
      File.write!(path, unquote(flag) <> "\n")

      assert_raise Mix.Error, ~r/Incompatible vm.args.eex/, fn ->
        IExStartupCheck.check_vm_args!(release)
      end
    end
  end

  test "still requires a vm.args.eex template", %{release: release} do
    assert_raise Mix.Error, ~r/Missing required/, fn ->
      IExStartupCheck.check_vm_args!(release)
    end
  end
end
