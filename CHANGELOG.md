# Release Notes

## Nerves v0.11.0

  * Bug Fixes
    * Including the entire artifact checksum in artifact download file name was causing issues with
      file encryption libraries. Fixed by changing the artifact download name to only
      use the first 7 of the artifact checksum.

## Nerves v0.10.1

  * Bug Fixes
    * Ensure the artifact cache dir is clean and created before putting artifacts.

## Nerves v0.10.0

  * Enhancements
    * Call `bootstrap/1` on any package that defines a platform
    * Added Nerves.Utils.File.tar helper for creating archives
    * Only apply the host tuple `portable` to packages with type `system`
    * Packages other then toolchains and systems can override their artifact
      paths using an env var of ther app name. For example. a package called
      `:host_tool` would be able to override the artifact path by setting
      `HOST_TOOL` in the environment.
    * Allow any package that declares a provider to create an artifact.
    * Fixed up test fixtures and added integration test.

  * Bug Fixes
    * Do not raise when trying to make a directory when putting an artifact in
      the global cache.
    * Ensure the Nerves environment has been started when calling `nerves
      artifact`

## Nerves v0.9.4

  * Bug Fixes
    * Fix artifact archiver to use `Artifact.download_name/1` instead of
      `Artifact.name/1`. Fixes issues with the Docker provider and
      `mix nerves.artifact`
    * Fix issue with `nerves.system.shell` not rendering properly

## Nerves v0.9.3

  * Bug Fixes
    * Artifact download_path should use download_name. This was causing a
      mismatch between dl files from buildroot and the resolver causing it to
      have to download them twice
    * Fixed issue with compiling certain nerves packages when calling
      `mix deps.compile`

## Nerves v0.9.2

  * Bug Fixes
    * Fixed issue where env var artifact path overides were being calculated
      instead of honored.

## Nerves v0.9.1

  * Bug Fixes
    * Fixed issue with artifact default path containing duplicate names
    * `Nerves.Env.host_os` can be set from `$HOST_OS` for use with canadian
      cross compile
    * `Nerves.Env.host_arch` can be set from `$HOST_ARCH` for use with canadian
      cross compile
    * mkdir -p on `Artifact.base_dir` before trying to link to build path
      artifacts
    * raise if artifact_urls are not binaries.

## Nerves v0.9.0

* Update Notes

Starting in Nerves v0.9.0, artifacts will no longer be fetched during `mix
compile`. Artifact archives are intended to be fetched following `mix deps.get`.
To handle this, you will need to update your installed version of
`nerves_bootstrap` by calling `mix nerves.local`. After updating
`nerves_bootstrap`, you should update your `mix.exs` file to add the new
required mix aliases found there. A helper function is available named
`Nerves.Bootstrap.add_aliases` that you can pipe your existing aliases to like
this:

```elixir
  defp aliases(_target) do
    [
      # Add custom mix aliases here
    ]
    |> Nerves.Bootstrap.add_aliases()
  end
```

Also, update your nerves dependency to:

`{:nerves, "~> 0.9", runtime: false}`

* API Changes
  * Moved `Nerves.Package.Providers` to `Nerves.Artifact.Providers`
  * Moved `Nerves.Package.Providers.HTTP` to `Nerves.Artifact.Resolver`
  * `Nerves.Artifact.Resolver` no longer implements the
    `Nerves.Artifact.Provider` behaviour.

* Enhancements
  * Added Mix task `nerves.artifact.get`. Use to fetch the artifact archive from an
    `artifact_url` location. Once downloaded its checksum will be checked against
    `artifact_checksum` from the `nerves_package` config in `mix.exs`. The Mix task
    `nerves.deps.get` will recursively call `nerves.artifact.get` to fetch archives.
  * Added Mix task `nerves.artifact.archive`. This task will produce the
    artifact archive and artifact checksum file which are used when calling
    `nerves.artifact.get`.
  * Nerves packages can override the Provider in the `nerves_package` config
    in `mix.exs` using the keys `provider` and `provider_opts`. This is
    useful to force a package to build using a specific provider like
    `Nerves.Artifact.Providers.Docker`. See the [package configuration docs](https://hexdocs.pm/nerves/systems.html#package-configuration)
    for more information.
  * Added `artifact_sites` to the `nerves_package` config. Artifact sites
    are helpers that are useful for cleanly specifying locations where artifacts
    can be fetched. If you are hosting your artifacts using Github relases
    you can specify it like this:
    ```elixir
    artifact_sites: [
      {:github_releases, "orginization/project"}
    ]
    ```

    You can also specify your own custom server location by using the `:prefix`
    helper by passing a url or file path:
    ```elixir
    artifact_sites: [
      {:prefix, "/path/to/artifacts"}
      {:prefix, "https://my_bucket.s3-east.amazonaws.com/artifacts"}
    ]
    ```
    Artifact sites will be tried in order until one succeffully downloads the
    artifact.
* Bug Fixes
  * Fixed issue with `Nerves.Utils.HTTPResolver` crashing when missing the
    `content-disposition` and `content-length` headers.
  * Run integrity check on tar files to validate they are not corrupted on
    download.

## Nerves v0.8.3

* Bug Fixes
  * Revert plugin Nerves in new project generator until
    the fix can be made in distillery.
    This issue was causing the release to contain compiled
    libraries from the host instead of the target.
    The error would look similar to this
    ```
    Got:
    ELF 64-bit LSB relocatable, x86-64, version 1

    If binary, expecting:
    ELF 32-bit LSB executable, ARM, EABI5 version 1, interpreter /lib/ld-linux.so.3, for GNU/Linux 4.1.39
    ```
    You can fix this by updating and regenerating the new project.

## Nerves v0.8.2

* Enhancements
  * Added [contributing guide](https://github.com/nerves-project/nerves/blob/master/docs/CONTRIBUTING.md)
  * Improved error messages when `NERVES_SYSTEM` or `NERVES_TOOLCHAIN` are unset.

* Bug Fixes
  * Don't override the output_dir in the Distillery Plugin.

## Nerves v0.8.1

* Bug Fixes
  * Fixed an error in the `Nerves` Distillery plugin that was causing the following error message:
    ```
    Plugin failed: no function clause matching in IO.chardata_to_string/1
    ```

## Nerves v0.8.0

* Enhancements
  * Removed legacy compiler key from the package struct. The `nerves_package` compiler will be chosen by default.
  * Simplified the distillery relase config by making Nerves a distillery plugin
  * Skip archival phase when making firmware.
  * Allow the progress bar to be disabled for use in CI systems by setting `NERVES_LOG_DISABLE_PROGRESS_BAR=1`
  * Deprecate nerves.exs. The contents of nerves.exs files have been moved into mix.exs under the project key `nerves_package`

* Bug Fixes
  * raise an exception when the artifact build encounters an error

## Nerves v0.7.5

* Enhancements
  * Docker
    * Reduced the image size by optimizing docker file.
    * Images are pulled from Docker Hub instead of building locally.
    * Containers are transient and build files are stored in docker volumes.
    * NERVES_BR_DL_DIR is mounted as a host volume instead of a docker volume.

* Bug Fixes
  * Docker
    * Fixed issue where moving the project location on the host would require
      the container to be force deleted.

## Nerves v0.7.4

* Bug Fixes
  * Make sure the path NERVES_DL_DIR exists before writing artifacts to it.

## Nerves v0.7.3

* Enhancements
  * [mix firmware.image] remove the need to pass an image name. Default to the app name.
  * [mix] added shortdocs to all mix tasks.
  * [fwup] bumped requirement to ~> 0.15 and support 1.0.0 pre release.
  * Cache downloads to ~/.nerves/dl or $NERVES_DL_DIR if defined.

## Nerves v0.7.2

* Bug Fixes
  * Fixed issue where `nerves.system.shell` would hang and load improperly.
* Enhancements
  * Deprecated the `rootfs_additions` configuration option, to be superseded by
    the `rootfs_overlay` option, which matches the convention used by the
    Buildroot community.

## Nerves v0.7.1

* Bug Fixes
  * The `nerves.system.shell` Mix task should not do `make clean` by default.
* Enhancements
  * The "Customizing Your Own Nerves System" documentation has been updated to
    include the `mix nerves.system.shell` functionality, including a blurb to
    recommend running a clean build any time it's not working as expected.

## Nerves 0.7.0

* Bug Fixes
  * Try to include the parent project when loading Nerves packages
  * Better error message from the Docker provider when Docker is not installed
  * Delete system artifact directories only when instructed by `mix nerves.clean` on Linux.
    This prevents triggering a full rebuild for every change made to a custom system.
* Enhancements
  * Added support for the new `nerves.system.shell` task, provided by
    `nerves_bootstrap`, to `Nerves.Package.Providers.Docker` and
    `Nerves.Package.Providers.Local`, which provides a consistent way to
    configure a Buildroot-based Nerves system on both OSX and Linux. This
    replaces the `nerves.shell` Mix task, which had not been fully implemented.
  * `mix firmware.burn` no longer asks for your password if using Linux and have
     read/write permissions on the SD card device.

## Nerves 0.6.1

* Bug Fixes
  * Docker Provider: Fix version parsing issue when major, minor, or patch contains leading zeros.

## Nerves 0.6.0

* Bug Fixes
  * Require Nerves Packages to have a version
* Enhancements
  * Propagate Mix.Project.config settings into the firmware metadata
  * Removed checksum from docker container name. Docker provider now only builds changes
  * Added Nerves.Env.clean for cleaning package providers

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
