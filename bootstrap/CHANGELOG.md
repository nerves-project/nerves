# nerves_bootstrap

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
