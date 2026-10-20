# CoverHelper

This library extends code coverage to the calls to mix that build firmware since
we want to make sure we have a totally clean environment when doing the
integration test builds.

When the calling VM is tracking coverage, `CoverHelper.mix/2` and
`CoverHelper.interactive_mix/3` launch Elixir with
[`priv/coverage_startup.exs`](priv/coverage_startup.exs) required before Mix starts.
The script instruments the parent project's Nerves test BEAMs using Erlang's
`:cover` API and exports results to the parent project's `cover` directory on
exit. This covers host and target commands, including early Nerves initialization,
without changing the project under test or requiring its dependencies to be built.
The parent project's test BEAMs must already exist.

Commands run normally when coverage is inactive. `deps.get` is also run without
coverage. Generate a combined HTML report from the exports with `mix test.coverage`.
