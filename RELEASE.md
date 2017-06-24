# Nerves Release Procedure

* Bump `nerves_system_*` releases first, if needed (e.g. make sure they support the intended `nerves` version)
* Create a branch/PR for the Nerves & Bootstrap release (e.g. `0.5.x`)
  * Remove the `-dev` from the `VERSION` files on `nerves` and `nerves_bootstrap` (e.g. `0.5.0-dev` to `0.5.0`)
  * Update `mix nerves.new` Mix task to use the latest `nerves`, `nerves_runtime`, and `nerves_bootstrap`
  * Review commits since previous release and make sure `CHANGELOG.md` is accurate
* Obtain review approval from at least one other Nerves team menber
* Merge the release PR into `master` (with `--no-ff`) and tag the merge commit as `vX.Y.Z`
* Publish `nerves` to Hex (`mix hex.publish`)
* Publish `nerves_bootstrap` to GitHub
  * Build the archive (`cd bootstrap; archive.build -o nerves_bootstrap.ez`)
  * Copy the `nerves_bootstrap.ez` file over the existing one in the [nerves-project/archives](https://github.com/nerves-project/archives) repository
  * Also copy it to `nerves_bootstrap-x.y.z.ez` in that repository for future reference
* On the `master` branch, bump the revision to the next planned release number and append `-dev` (e.g. `0.5.1-dev` or `0.6.0-dev` after a `0.5.0` release)
