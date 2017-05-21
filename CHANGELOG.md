# Release Notes

## Nerves 0.5.2
* BugFixes
  * Handle redirects manually as a fix to OTP 19.3 caused by https://bugs.erlang.org/browse/ERL-316

## Nerves 0.5.1
* BugFixes
  * Handle redirects manually as a fix to OTP 19.3 caused by https://bugs.erlang.org/browse/ERL-316

## Nerves 0.5.0
* Bug Fixes
  * `:nocache` the HTTP provider if the download list is empty
  * return an error when tar is unsuccessful at decompressing an artifact
  * return `:error` for any error in downloading artifacts
  * clean up temp files after downloading artifacts
  * expand path before comparing for dep type: Fixes path deps in umbrella
  * clean up artifact dir before copying new artifact
* Enhancements
  * changed console output for higher visibility Nerves compiler messages
  * added ability to specify the images_path in the Mix.Project config
  * changed default images_path to `#{build_path}/nerves/images`
  * updated docs to reflect changes made to project structure
  * added `mix nerves.info` task. Can be used to gain information about the Nerves env

## Nerves 0.4.8
* Bug Fixes
  * removed `--silent` from `mix release.clean` for compatibility with `:distillery ~> 1.2.0`

## Nerves 0.4.7
* Bug Fixes
  * [Providers.Local] Fix return error on non zero exit status code
  * Fixed IO stream split to handle ANSI code case regression

## Nerves 0.4.6
* Bug Fixes
  * fix artifact http download manager to take as long as it needs unless idle for more than 2 minutes.
  * [Providers.Docker] Fixed IO stream parsing to handle occasions where ANSI codes are not being passed.
  * loosened dependency on distillery


## Nerves 0.4.5
* Bug Fixes
  * catch exits from mix release.clean when calling mix firmware

## Nerves 0.4.4
* Bug Fixes
  * return an `{:error, message}` response from the http provider when a resource is not found

## Nerves 0.4.3
* Enhancements
  * Mix will display a progress bar, percentage, and total / expected bytes when downloading artifacts.
  * Added task `mix firmware.image my_app.img` for producing images for use with applications like dd
  * Silenced output from distillery which would contain misleading information for the nerves project

* Bug Fixes
  * Docker provider could potentially produce application id's that were invalid


## Nerves 0.4.2
* Bug Fixes
  * Fixed issue where artifact paths could not be set by system env var
  * Mix Task `nerves.release.init` was failing due to missing template. Include priv in hex package files.

## Nerves 0.4.1
* Bug Fixes
  * Do not stop the Nerves.Env at the end of the package compiler. This would cause the packages to resolve the wrong dep type.
  * Fixed issue where remote artifacts would not be globally cached
  * Fixed issue with package compiler where it would always force systems to be built

## Nerves 0.4.0
* Enhancements
  * Improved test suite
  * Added documentation for modules
  * Consolidated the Nerves Environment to the Nerves package

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
