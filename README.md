# Nerves

Craft and deploy bulletproof embedded software in Elixir

[![Backers on Open Collective](https://opencollective.com/nerves-project/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/nerves-project/sponsors/badge.svg)](#sponsors)
[![CircleCI](https://circleci.com/gh/nerves-project/nerves/tree/master.svg?style=svg)](https://circleci.com/gh/nerves-project/nerves/tree/master)
[![Hex version](https://img.shields.io/hexpm/v/nerves.svg "Hex version")](https://hex.pm/packages/nerves)

## Host Requirements

* Mac OS 10.10+
* 64-bit Linux (tested on Debian / Ubuntu / Redhat / CentOS)
* Windows 10 with [Windows Subsystem for Linux](https://msdn.microsoft.com/en-us/commandline/wsl/install_guide) (experimental)
* Raspberry Pi 3 (experimental)
* Elixir ~> 1.4

See [Installation Docs](https://hexdocs.pm/nerves/installation.html) for
software dependencies.

## Quick-Reference

### Generating a New Nerves Application

```bash
mix nerves.new my_app
```

### Building Firmware

```bash
export MIX_TARGET=rpi3
mix deps.get      # Fetch the dependencies
mix firmware      # Cross-compile dependencies and create a .fw file
mix firmware.burn # Burn firmware to an inserted SD card
```

**Note:** The `mix firmware.burn` target relies on the presence of `ssh-askpass`. Some
users may need to export the `SUDO_ASKPASS` environment variable to point to their askpass
binary.  On Arch Linux systems, this is in `/usr/lib/ssh/ssh-askpass`

## Docs

[Installation Docs](https://hexdocs.pm/nerves/installation.html)

[Getting Started](https://hexdocs.pm/nerves/getting-started.html)

[Frequently-Asked Questions](https://hexdocs.pm/nerves/faq.html)

[Systems](https://hexdocs.pm/nerves/systems.html)

[Targets](https://hexdocs.pm/nerves/targets.html)

[User Interfaces](https://hexdocs.pm/nerves/user-interfaces.html)

[Advanced Configuration](https://hexdocs.pm/nerves/advanced-configuration.html)

## Contributors

This project exists thanks to all the people who contribute.
<a href="https://github.com/nerves-project/nerves/graphs/contributors"><img src="https://opencollective.com/nerves-project/contributors.svg?width=890" /></a>

Please see our [Contributing Guide](/CONTRIBUTING.md) for details on how you can
contribute in various ways.

## Platinum Sponsors

<!-- When updating, make sure that https://github.com/nerves-project/nerves-project.github.com/blob/master/index.md is updated as well. -->

<a href="https://www.letote.com/careers" target="_blank"><img width="150" height="150" src="http://nerves-project.org/images/sponsorship/letote.png"></a>

## Silver Sponsors

<a href="https://www.smartrent.com" target="_blank"><img width="150" height="150" src="http://nerves-project.org/images/sponsorship/smartrent.png"></a>

[[Become a metal level sponsor]](http://nerves-project.org/sponsoring)

## Backers

Thank you to all our backers! 🙏 [[Become a backer](https://opencollective.com/nerves-project#backer)]

<a href="https://opencollective.com/nerves-project#backers" target="_blank"><img src="https://opencollective.com/nerves-project/backers.svg?width=890"></a>

## Sponsors

Support this project by becoming a sponsor. Your logo will show up here with a link to your website. [[Become a sponsor](https://opencollective.com/nerves-project#sponsor)]

<a href="https://opencollective.com/nerves-project/sponsor/0/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/1/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/2/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/3/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/4/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/5/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/6/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/7/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/8/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/9/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/9/avatar.svg"></a>

Copyright (C) 2015-2017 by the Nerves Project developers <nerves@nerves-project.org>
