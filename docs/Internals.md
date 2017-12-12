# Internals

The nerves bootstrapping process has several steps.  Its goal is to locate 
the "system", compile it, and use the compiled system to setup the cross 
compile environment.

## Call Tree

Below is a brief sketch of the call tree for the boostrap.  It is intended
to be a "10,000 ft" overview.

### mix firmware
* alias
  * nerves.precompile
    * NERVES_PRECOMPILE = 1
    * Mix.Tasks.Nerves.Env
      * Mix.Tasks.Deps.Loadpaths.run ["--no-compile"]
      * Mix.Tasks.Deps.Compile.run ["nerves", "--include-children"]
      * Nerves.Env.start()
        * load_packages()
            * Mix.Project.deps_paths
              * Package.config_path
              * Package.load_config
                * provider()
              * validate_packages()
    * Mix.Tasks.Deps.Compile Nerves.Env.system.app
    * Mix.Tasks.Compile.run(--no-deps-check) Only if parent == system_app
    * NERVES_PRECOMPILE = 0
    * Mix.Tasks.Nerves.Loadpaths.run()
      * Mix.task.run(nerves.env) Nerves.Env
        * Nerves.Env.start() ?? See above
      * Nerves.Env.bootstrap()
        * system_path()
          * Nerves.Env.system()
            * Nerves.Package.Artifact.dir()
              * System.get_env(env_var(pkg)) NERVES_SYSTEM
        * toolchain_path()
          * Nerves.Env.toolchain()
            * Nerves.Package.Artifact.dir()
              * System.get_env(env_var(pkg)) NERVES_TOOLCHAIN
        * platform.bootstrap(pkg) Nerves.Env.system.platform ||Nerves.Env.system.config[:build_platform]
          * nerves_env.exs Nerves.System.BR
  * deps.precompile

### nerves_package
  * Nerves.Env.start
  * Nerves.Env.enabled? and Nerves.Package.stale?(package, toolchain)
    * Nerves.Package.artifact(package, toolchain)
      * pkg.provider.artifact(pkg, toolchain, opts) [Nerves.Package.Providers.HTTP, Nerves.Package.Providers.Local]
* firmware

# Key Files/Variables

NERVES_SYSTEM 
  * Path to the nerves_system_* folder
  * Has to be defined at Nerves.Env.bootstrap() or system blows up

NERVES_TOOLCHAIN 
  * Path to the toolchain
  * Has to defined at Nerves.Env.bootstrap() or systems blows up

nerves_env.exs
  * Sets the cross compile flags
  * NERVES_SYSTEM and NERVES_TOOLCHAIN must be defined prior
  * Everything thing run after will try to cross compile

nerves_system/.nerves/artifacts/nerves_system_*
   * "package" directory
   * Gets fetched from nerves_env.exs artifact_url
