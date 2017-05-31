# nerves_bootstrap

## v0.4.0-dev
  * Enhancements
    * nerves.new
      * lock files are split by target
      * Target dependencies are explicitly broken out in mix.exs through passing
        `--target` to the generator. Defaults to declaring all officially supported
        Nerves Targets.
      * A default cookie is generated and placed in the vm.args. the cookie can
        be set by passing `--cookie`  

## v0.3.1
  * Bug Fixes
    * Added support for OTP 20: Fixes issue with RegEx producing false positives.

## v0.3.0
* Enhancements
  * nerves.new
    * defaults to Host target env
    * includes nerves_runtime
    * prompt to install deps and run nerves.release.init
    * unset MIX_TARGET when generating a new project
* Bug Fixes
  * removed rel/.gitignore from new project generator

## v0.2.2
* Enhancements
  * Added `mix local.nerves` for updating the bootstrap archive

## v0.2.1
* Bug Fixes
  * update nerves dep in new project generator to 0.4.0
* Enhancements
  * Additional debug output when setting `NERVES_DEBUG=1`
  * Ability to output information about the loaded Nerves env via `mix nerves.env --info`

## v0.2.0
  * Enhancements
    * Support for nerves_package compiler

## v0.1.4
  * Bug Fixes
    * Do not warn on import Supervisor.Spec
    * Silence alias location messages unless NERVES_DEBUG=1
  * Enhancements
    * Support for Elixir 1.3.2

## v0.1.3
  * Enhancements
    * Support for elixir ~> 1.3.0-rc.0
