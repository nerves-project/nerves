System.put_env("NERVES_PATH", File.cwd!())

ExUnit.start exclude: [:skip]
Code.compiler_options(ignore_module_conflict: true)
