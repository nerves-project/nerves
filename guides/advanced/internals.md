<!--
  SPDX-FileCopyrightText: 2017 Michael Schmidt
  SPDX-FileCopyrightText: 2018 Connor Rigby
  SPDX-FileCopyrightText: 2018 Justin Schneck
  SPDX-FileCopyrightText: 2020 Kian-Meng, Ang
  SPDX-License-Identifier: CC-BY-4.0
-->
# Nerves Internals

The nerves bootstrapping process has several steps.  Its goal is to locate
the "system", compile it, and use the compiled system to setup the cross
compile environment.

## Call Tree

Below is a brief sketch of the call tree for the bootstrap.  It is intended
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
                * build_runner()
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
            * Nerves.Artifact.dir()
              * System.get_env(env_var(pkg)) NERVES_SYSTEM
        * toolchain_path()
          * Nerves.Env.toolchain()
            * Nerves.Artifact.dir()
              * System.get_env(env_var(pkg)) NERVES_TOOLCHAIN
        * platform.bootstrap(pkg) Nerves.Env.system.platform ||Nerves.Env.system.config[:build_platform]
          * nerves_env.exs Nerves.System.BR
  * deps.precompile

### nerves_package
  * Nerves.Env.start
  * Nerves.Env.enabled? and Nerves.Artifact.stale?(package)
    * Nerves.Package.artifact(package, toolchain)
      * pkg.build_runner.artifact(pkg, toolchain, opts) [Nerves.Artifact.BuildRunners.HTTP, Nerves.Artifact.BuildRunners.Local]
* firmware

## Key Files/Variables

The following are the key parts of the bootstrap.  Note that NERVES_SYSTEM and
NERVES_TOOLCHAIN can be defined before running `mix firmware` to point to a
trusted decompressed system or toolchain. This is useful in situations where
you produce a system directly using Buildroot and want to force Nerves to use it.

### NERVES_SYSTEM
  * Path to the `nerves_system_*` folder
  * Has to be defined at Nerves.Env.bootstrap() or system blows up
  * Exists only if the system dependency is being included from a source other than hex.
    * When a system is being sourced from hex, it will attempt to place the uncompressed artifact in the global path located at ~/.nerves/artifacts or $NERVES_ARTIFACTS_DIR

### NERVES_TOOLCHAIN
  * Path to the toolchain
  * Has to defined at Nerves.Env.bootstrap() or systems blows up

### nerves_env.exs
  * Sets the cross compile flags
  * NERVES_SYSTEM and NERVES_TOOLCHAIN must be defined prior
  * Everything run after will try to cross compile

### nerves_system/.nerves/artifacts/nerves_system_*
   * "package" directory
   * Gets fetched from nerves_env.exs artifact_url
