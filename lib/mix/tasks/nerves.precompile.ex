defmodule Mix.Tasks.Nerves.Precompile do
  @moduledoc false
  use Mix.Task
  import Mix.Nerves.IO

  @switches [loadpaths: :boolean]

  @impl Mix.Task
  def run(args) do
    debug_info("Precompile Start")

    # Note: We have to directly use the environment variable here instead of
    # calling Nerves.Env.enabled?/0 because the nerves.precompile step happens
    # before the nerves dependency is compiled, which is where Nerves.Env
    # currently lives. This would be improved by moving Nerves.Env to
    # nerves_bootstrap.
    unless System.get_env("NERVES_ENV_DISABLED") do
      System.put_env("NERVES_PRECOMPILE", "1")

      {opts, _, _} = OptionParser.parse(args, switches: @switches)

      Mix.Task.run("nerves.env", [])

      {app, deps} =
        Nerves.Env.packages()
        |> Enum.split_with(&(&1.app == Mix.Project.config()[:app]))

      (deps ++ app)
      |> compile_check()
      |> Enum.each(&compile/1)

      Mix.Task.reenable("deps.compile")
      Mix.Task.reenable("compile")

      System.put_env("NERVES_PRECOMPILE", "0")

      if opts[:loadpaths] != false, do: Mix.Task.rerun("nerves.loadpaths")
    end

    debug_info("Precompile End")
  end

  defp compile(%{app: app}) do
    if Mix.Project.config()[:app] == app do
      Mix.Tasks.Compile.run([app, "--include-children"])
    else
      Mix.Tasks.Deps.Compile.run([app, "--no-deps-check", "--include-children"])
    end
  end

  defp error_on_stale_nerves_package?(package) do
    # Detect packages that need to be rebuilt by the Nerves package compiler
    # and that the user hasn't explicitly marked as `compile: true`.  These
    # universally take long to build so force the user to acknowledge it.
    Mix.Project.config()[:app] != package.app and
      :nerves_package in Map.get(package, :compilers, Mix.compilers()) and
      Nerves.Artifact.expand_sites(package) != [] and
      Nerves.Artifact.stale?(package) and
      package.dep_opts[:compile] != true
  end

  defp compile_check(packages) do
    case Enum.filter(packages, &error_on_stale_nerves_package?/1) do
      [] ->
        packages

      stale_packages ->
        stale_package_text = for package <- stale_packages, into: "", do: "\n  #{package.app}"
        example = List.first(stale_packages)

        Mix.raise("""

        The following Nerves packages need to be built:
        #{stale_package_text}

        The build process for each of these can take a significant amount of
        time so the maintainers have listed URLs for downloading pre-built packages.
        If you have not modified these packages, please try running `mix deps.get`
        or `mix deps.update` to download the precompiled versions.

        If you have limited network access and are able to obtain the files via
        other means, copy them to `~/.nerves/dl` or the location specified by
        `$NERVES_DL_DIR`.

        If you are making modifications to one of the packages or want to force
        local compilation, add `nerves: [compile: true]` to the dependency. For
        example:

          {:#{example.app}, "~> #{example.version}", nerves: [compile: true]}

        If the package is a dependency of a dependency, you will need to
        override it on the parent project with `override: true`.
        """)
    end
  end
end
