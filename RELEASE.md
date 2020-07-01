# Nerves Release Procedure

* Bump `nerves_system_*` releases first, if needed (e.g. make sure they support
  the intended `nerves` version)
* Create a branch/PR for the Nerves release (e.g. `0.5.x`)
  * Remove the `-dev` from the `VERSION` files on `nerves`
  * Review commits since previous release and make sure `CHANGELOG.md` is
    accurate
* Obtain review approval from at least one other Nerves team member
* Merge the release PR into `main` (with `--no-ff`) and tag the merge commit
  as `vX.Y.Z`
* Publish `nerves` to Hex (`mix hex.publish`)
* On the `main` branch, bump the revision to the next planned release number
  and append `-dev` (e.g. `0.5.1-dev` or `0.6.0-dev` after a `0.5.0` release)
