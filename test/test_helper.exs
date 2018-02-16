System.put_env("NERVES_PATH", File.cwd!())

File.cwd!()
|> Path.join("test")
|> Path.join("tmp")
|> File.rm_rf()

Code.compiler_options(ignore_module_conflict: true)
Mix.shell(Mix.Shell.Process)

ExUnit.start(exclude: [:skip])
