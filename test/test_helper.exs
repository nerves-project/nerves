System.put_env("NERVES_PATH", File.cwd!())

File.cwd!()
|> Path.join("test_tmp")
|> File.rm_rf()

Application.start(:logger)
Logger.configure(handle_sasl_reports: true)
Logger.remove_backend(:console)

Code.compiler_options(ignore_module_conflict: true)
Mix.shell(Mix.Shell.Process)

System.put_env("NERVES_LOG_DISABLE_PROGRESS_BAR", "1")

# Clear the project stack in preparation for loading and unloading fixtures
Mix.ProjectStack.clear_stack()

config =
  case System.get_env("CI") do
    nil ->
      []

    _ ->
      # CircleCI needs a long assert receive timeout.
      # The JUnitFormatter lets CircleCI parse the error messages.
      [assert_receive_timeout: 500, formatters: [ExUnit.CLIFormatter, JUnitFormatter]]
  end

ExUnit.start(config)
