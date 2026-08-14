<!--
  SPDX-FileCopyrightText: None
  SPDX-License-Identifier: CC0-1.0
-->
# Contributing to Nerves

We're excited that you want to contribute to the Nerves project!

First, we want the Nerves community to be welcoming and helpful to everyone.
We expect all community members to follow our [Code of Conduct].

## Before you start

- Check existing issues and pull requests before starting work
- Discuss large changes before investing significant effort
- Keep pull requests focused on a single problem

In general, we review shorter PRs more quickly. If you find grammar, formatting,
or spelling issues, please send them in their own PRs even if they seem trivial.

When in doubt, we're happy to help. We're available on the [Nerves
Discord] and it's fine to create a GitHub issue.

## Development workflow

- Fork the repository and create a branch for your change
- Squash your commits to remove intermediate work
- Update the documentation
- Run `mix format`, `mix test`, and `mix credo`

After opening a pull request, contributors are responsible for monitoring CI
results and fixing any failures introduced by their changes.

## Commit messages

Write commit messages yourself.

We consider Git history important, and the principles behind [Common Changelog]
are a good guide for writing it. Describe the impact of a change rather than its
implementation, and write titles that stand on their own away from the diff. We
do not follow the specification strictly and we do not use conventional commit
tags.

Commit message titles should describe the change in 50 characters or fewer. Use
sentence case and the imperative mood, as if finishing the sentence "This commit
will...".

Good commit messages briefly explain:

- What changed
- Why it changed
- Any important constraints or tradeoffs

Call out breaking changes in the commit body.

Avoid boilerplate or excessively verbose generated commit messages.

### Licensing and copyright assignment

This project follows the [REUSE Specification].

When modifying a file, add your name and the current year to the copyright
notices if not already present. Contributors only need to add themselves once
per file.

If this step is missed, copyright attribution will be added later using
information from Git history.

Unless explicitly agreed otherwise by the maintainers:

- Source code contributions must be licensed under Apache-2.0
- Standalone documentation must be licensed under CC-BY-4.0
- Trivial configuration files must be licensed under CC0-1.0

By submitting a contribution, you agree to license your work under the terms
applicable to the files you modify.

Validate licensing and copyright changes by running `reuse lint`.

## Pull requests

Opening a pull request is a statement that the change is finished and that you
understand it. Reviewers need to understand the problem, why it matters, and why
you solved it this way. They will catch mistakes, but review is not where
correctness gets established for the first time. The project maintains what it
merges, so submit work you could still explain a year from now.

Draft pull requests and branches are encouraged for anything earlier than that.
Some ideas are easier to see in code than to describe, and a draft gives
everyone something concrete to work from while the discussion continues in
review comments or on Discord.

Try to keep pull requests to one commit by squashing intermediate commits
together. If you find that multiple commits are better, this is likely a sign
that two pull requests should be made. We are happy to receive stacked PRs if
the commits depend on each other.

Use the commit title and content for the pull request. Add notes for reviewers
to the pull request description, such as when a unit test was already failing
before your change.

Concise explanations are preferred over exhaustive summaries.

## AI-assisted contributions

Contributions are made by people, not tools.

AI tools may be used to assist with development. Contributors are responsible
for everything they submit and should be able to explain their changes during
review. Review AI-generated code as carefully as you would review a stranger's,
and confirm that it compiles, runs, and is tested before sending it.

Pull request titles, descriptions, issue reports, commit messages, and review
discussions should be written by the contributor. Using AI to translate or
tighten your own writing is fine. Using it to write in your place is not.
Follow the [Commit messages](#commit-messages) guidance as well, since Git
history is what explains a change long after review ends.

Do not submit lengthy AI-generated summaries, explanations, or code
walkthroughs. Reviewers can chat with an LLM on their own time about your
contributions, if they desire - it is more important that the submitter convey
their own understanding in their own words.

A few things that come up repeatedly in review:

- Comment on an open issue before pointing a coding agent at it.
- Keep the change focused. Delete unrelated refactoring, speculative
  abstractions, defensive error handling, and comments that restate the code.
- Verify claims before making them. Unconfirmed bug reports, and especially
  unconfirmed security reports, cost maintainers a lot of time.
- Don't reference functions, options, or behavior without checking that they
  exist.
- Don't add AI tool configuration such as `AGENTS.md` or `CLAUDE.md` without
  asking first.
- The licensing terms above apply to AI-assisted contributions. Only submit
  work that you have the right to license.

Credit tools with an `Assisted-by` trailer:

```text
Assisted-by: AGENT_NAME:MODEL_VERSION
```

For example:

```text
Assisted-by: Claude Code:claude-opus-5
```

Do not add `Signed-off-by` tags. Nerves does not use them.

## Reporting bugs

**Please do not report security vulnerabilities through public GitHub issues, pull requests, or discussions. See [SECURITY.md]**

When reporting bugs, include:

- Steps to reproduce
- Expected behavior
- Actual behavior
- Library version numbers

Minimal reproducible examples are always appreciated.

## Become a backer or sponsor through OpenCollective

The Nerves project has set up an [OpenCollective site] that allows individuals
and companies to make one-time or recurring financial contributions to cover the
cost of maintaining the project.

<!-- Links -->

[Code of Conduct]: CODE_OF_CONDUCT.md
[Common Changelog]: https://common-changelog.org/
[Nerves Discord]: https://discord.gg/7TqSpepHw7
[nerves repository]: https://github.com/nerves-project/nerves
[OpenCollective site]: https://opencollective.com/nerves-project
[REUSE Specification]: https://reuse.software/
[SECURITY.md]: SECURITY.md
