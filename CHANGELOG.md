# Release Notes

## Nerves 0.3.4-dev
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
