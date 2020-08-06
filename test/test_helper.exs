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

# Clear the project stack in preperation for loading and unloading fixtures
Mix.ProjectStack.clear_stack()

ExUnit.start(exclude: [:skip])
