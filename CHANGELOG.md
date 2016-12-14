# Release Notes

## Nerves 0.4.1-dev
* Bug Fixes
  * Do not stop the Nerves.Env at the end of the package compiler. This would cause the packages to resolve the wrong dep type.
  * Fixed issue where remote artifacts would not be globally cached
  * Fixed issue with package compiler where it would always force systems to be built

## Nerves Bootstrap 0.2.1-dev
* Enhancements
  * support for package compiler

## Nerves 0.4.0
* Enhancements
  * Improved test suite
  * Added documentation for modules
  * Consolidated the Nerves Environment to the Nerves package

## Nerves Bootstrap 0.2.0
* Enhancements
  * support for package compiler

## Nerves 0.4.0-rc.0
* Enhancements
  * Consolidated compilers into `nerves_package`.
  * Removed dependency for `nerves_system`
  * Removed dependency for `nerves_toolchain`
  * Added Docker provider for building custom systems on machines other than linux

## Nerves 0.3.4
* Bug Fixes
  * Fixed regression with `mix firmware.burn` to allow prompts
* Enhancements
  * Added ability to override task in `mix firmware.burn`. You can now pass `-t` or `--task` to perform `upgrade` or anything else. Default is `complete`

## Nerves 0.3.3
* Bug Fixes
  * Updated nerves.precompile / loadpaths to support Elixir 1.3.x aliases.
* Enhancements
  * Removed dependency on porcelain

## Nerves 0.3.2
* Bug Fixes
  * Support for elixir 1.3.0-dev
  * Invoke `nerves.loadpaths` on preflight of `mix firmware` and `mix firmware.burn`. Fixes `ERROR: It looks like the system hasn't been built!`

## Nerves 0.3.1
* Enhancements
  * Perform host tool checks before executing scripts

## Nerves 0.3.0
* Enhancements
  * Added nerves_bootstrap archive
  * `mix firmware` Create firmware bundles from mix
  * `mix firmware.burn` Burn Firmware bundles to SD cards

## Nerves 0.2.0
* Enhancements
  * Added support for 0.4.0 system paths
