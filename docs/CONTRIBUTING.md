# Contributing to Nerves

We're very excited that you want to contribute to the Nerves project! There are
a lot of ways you can help out, some of which you may not have even considered
as being a contribution to the project.

Most importantly, we want the Nerves community to be welcoming and helpful to
everyone. We expect that all members of our community follow our [Code of
Conduct](CODE_OF_CONDUCT.md), regardless of whether the contribution is a
discussion in a Pull Request on GitHub, a conversation in the #nerves channel on
the [Elixir Slack], or any of the other items outlined below.

[Elixir Slack]: https://elixir-slackin.herokuapp.com/

## How you can help

We created this document to help you quickly turn your desire to contribute into
action. The sections below are roughly ordered by the amount of time investment
required, but we truly value contributions of all sizes. Many small
contributions by a large number of people will grow a stronger community and be
more inclusive for everyone.

## Try using Nerves and give us feedback

Whether you're just getting started or you've been using Nerves at work for a
long time, we would love to know where it's not meeting your needs.

* Is something missing, confusing, or wrong on [our website] or our [Getting
  Started Guide]?
* Were you trying to create a custom [Nerves system] and it didn't work like you
  expected?
* Did you have fun using Nerves and you just want to tell someone about it?

There are so many ways to communicate, each with advantages and disadvantages.
We prefer communication in the following order, but we understand that you may
have limited time to contribute and we would rather have one of the
less-preferred items than nothing at all.

One important exception is that **if you think you've found a security
vulnerability, do not open a GitHub Issue!** Please disclose these by emailing
[security@nerves-project.org] instead, so that we can work on releasing a fix
before the vulnerability is disclosed publicly.

1. Pull Request on GitHub

    If you're able to send us an improvement directly to the [documentation
    source] or [website source] code, that is extremely helpful! Don't worry
    about assigning labels, unless you also want to contribute to the [Triage
    process] outlined below.

    Also, be sure to check out the guidelines below about contributing code and
    documentation changes.

2. Issues on GitHub

    If you think you might have found a bug or documentation problem that you're
    not sure how to solve, open an Issue on the relevant GitHub repository. The
    Nerves project has a lot of [repositories], so if you're not sure which one
    is most relevant, it's OK to just open it in the main [nerves repository].

    If you have a question about how to use Nerves, we prefer that you use the
    [Nerves section] on [Elixir Forum] or the #nerves channel on the [Elixir
    Slack].

3. Questions on [Elixir Forum] (ideally in the [Nerves section])

    If questions and answers are captured in a forum like this, it makes them
    much easier for people to find later via search engine, as opposed to
    searching through a real-time conversation stream like Slack.

4. Blog about your project

    We love to see how people are using Nerves for fun and and for work. If you
    blog about a Nerves-based project, please consider posting a link somewhere
    that the community will notice it, like [Elixir Forum], [ElixirStatus], or
    the #nerves channel on the [Elixir Slack].

5. Chat with us on Slack

    We have a #nerves channel on the [Elixir Slack]. We'd be happy to have you
    drop in and let us know if you have questions or want to talk about a
    project you're working on, or thinking about working on.

[our website]: http://www.nerves-project.org
[Getting Started Guide]: https://hexdocs.pm/nerves/getting-started.html
[Nerves system]: https://hexdocs.pm/nerves/systems.html
[documentation source]: https://github.com/nerves-project/nerves/tree/master/docs
[website source]: https://github.com/nerves-project/nerves-project.github.com
[Triage process]: #issue-and-pull-request-triage
[repositories]: https://github.com/nerves-project
[nerves repository]: https://github.com/nerves-project/nerves
[Elixir Forum]: https://elixirforum.com
[Nerves section]: https://elixirforum.com/c/dedicated-sections/nerves
[ElixirStatus]: http://elixirstatus.com/
[security@nerves-project.org]: mailto:security@nerves-project.org

## Answer questions on the Elixir Forum and Slack channel

It takes a lot of time and energy to understand the context of a problem and
determine an appropriate solution. If you see a question posted on the [Elixir
Forum], you can help by:

* Making sure it gets marked as belonging to the [Nerves section]
* Asking clarifying questions to ensure that others will understand the context
* Offering your own advice or solutions if you can
* Pinging the core team in the #nerves-dev channel on Slack if it's stale

If you see a question posted in the #nerves channel on Slack, you can help by:

* Asking clarifying questions to ensure that others will understand the context
* Politely reminding the person that the answer will be more easily found later
  by others if it's posted to the [Elixir Forum] instead
* Helping to get it posted to the Forum or converted to a GitHub Issue to
  capture or summarize the discussion in Slack about it

## Become a Backer or Sponsor through OpenCollective

The Nerves project has set up an [OpenCollective site] that allows individuals
and companies to make one-time or recurring financial contributions to cover the
cost of maintaining the project.

[OpenCollective site]: https://opencollective.com/nerves-project

## Issue and Pull Request triage

In order to keep track of Issues and Pull Requests across all of our
repositories, we have a [Nerves Radar] project in our GitHub Organization.
Unfortunately, this isn't visible to the public because GitHub requires that you
be a member of the Organization to see Organization-level Projects. If you want
to get involved in this process, get in touch with us on Slack!

We currently don't have this process formalized, so feel free to contribute to
this document itself!

[Nerves Radar]: https://github.com/orgs/nerves-project/projects/1

## Code and documentation changes

If you're looking for a way to directly contribute to the code and
documentation, check our [repositories] for Issues that are labeled with
`kind:documentation`, `kind:bug`, or `kind:enhancement`. You can use the
`level:stater`, `level:intermediate`, and `level:advanced` labels to determine
how difficult we think it will be, whether you're looking for an easy first-time
contribution or an extra challenge.

If you're working on an Issue, feel free to set yourself as the **Assignee**,
and don't feel bad about removing yourself if you later decide that you're not
going to work on it. This helps us keep track of which Issues are currently
being worked-on, avoiding duplicated effort and Issues that get stale over time.

Working on your first Pull Request? You can learn how from this *free* series,
[How to Contribute to an Open Source Project on GitHub].

The core team has GitHub integrations with Slack, so we will be notified
immediately in the #nerves-dev channel about activity on GitHub Issues and Pull
Requests. We really appreciate you taking the time to record any Issues in
GitHub so that we don't lose track, but we all have busy lives outside of Nerves
work, so don't take it personally if it takes us a long time to respond.

[How to Contribute to an Open Source Project on GitHub]: https://egghead.io/series/how-to-contribute-to-an-open-source-project-on-github

### Licensing and copyright assignment

Copyright and licensing are very important to open-source software projects.
Nerves components fall under several licenses, so please review the license for
the project to which you are contributing. By contributing, you certify that you
have the right to submit the changes under the project's open source license and
assign copyright to the Nerves Project maintainers.

### Style guide for documentation

> NOTE: This is currently a work-in-progress. Feel free to suggest any missing
details!

#### Step-by-step command-line instructions

We want our instructions to be clear and user-friendly, even for people who are
not familiar with using a command-line interface. We also want to be consistent
within the Nerves documentation and with documentation in the broader community.
Therefore, we will show an appropriate prompt (e.g. `$`, `#`, or `iex(1)>`)
before the commands to be entered. This makes it slightly harder to
copy-and-paste several commands from the browser to the terminal, but allows the
reader to more easily differentiate what they need to type from what they should
expect to see as output. For example:

```bash
export MIX_TARGET=rpi3
mix firmware
mix firmware.burn
```

When showing an exact command to be run, we prefer placing the command line(s)
in a block with triple back-ticks and an appropriate text type, rather than
single inline back-ticks.

We encourage the use of small formatting changes, where possible and not
confusing, to emphasize or set apart the input from the output. We also
encourage the use of either three dots or an ellipsis to truncate long output or
code examples, only showing the relevant part. Where possible, show a truncation
in a code example using a comment rather than invalid code. For example:

```plain
$ iex -S mix
Erlang/OTP 19 [erts-8.2] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Compiling 6 files (.ex)
Generated example app
Interactive Elixir (1.4.2) - press Ctrl+C to exit (type h() ENTER for help)

iex(1)> System.cmd("date", [])
{"Fri Jun 16 09:52:12 EDT 2017\n", 0}

iex(2)>
```

> NOTE: I have artificially inserted blank lines before the `iex>` prompts to
make them stand out from the rest of the output more prominently.

```elixir
# custom_rpi3/mix.exs

defmodule CustomRpi3.Mixfile do

  # ...

  def project do
   [app: :custom_rpi3,
    version: @version,
    # ...
    ]
  end

  # ...

end
```
