# Nerves

Craft and deploy bulletproof embedded software in Elixir

[![Backers on Open Collective](https://opencollective.com/nerves-project/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/nerves-project/sponsors/badge.svg)](#sponsors)
[![CircleCI](https://circleci.com/gh/nerves-project/nerves/tree/main.svg?style=svg)](https://circleci.com/gh/nerves-project/nerves/tree/main)
[![Hex version](https://img.shields.io/hexpm/v/nerves.svg "Hex version")](https://hex.pm/packages/nerves)

## Host Requirements

* Mac OS 10.10+
* 64-bit Linux (tested on Debian / Ubuntu / Redhat / CentOS / Arch)
* Windows 10 with [Windows Subsystem for Linux 2](https://msdn.microsoft.com/en-us/commandline/wsl/install_guide) (experimental)
* Raspberry Pi 3 (experimental)
* Elixir ~> 1.9

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

[Compiling non-BEAM code](https://hexdocs.pm/nerves/compiling-non-beam-code.html)

[Customizing Systems](https://hexdocs.pm/nerves/customizing-systems.html)

## Contributors

This project exists thanks to all the people who contribute.
<a href="https://github.com/nerves-project/nerves/graphs/contributors"><img src="https://opencollective.com/nerves-project/contributors.svg?width=890" /></a>

Please see our [Contributing Guide](/.github/CONTRIBUTING.md) for details on how you can
contribute in various ways.

## Metal Level Sponsors

Metal level sponsors are companies that allow core team members to maintain and
extend Nerves for a portion of each work week. Nerves is not a product of any
one company. We also have a soft spot for supporting makers and hobbyists using
the BEAM, and it would be difficult to do this without them.

<a href="https://www.smartrent.com" target="_blank"><img width="200" height="100" src="https://www.nerves-project.org/hubfs/Very%20Logos%20Smart%20Rent.png"></a>

<a href="https://www.verypossible.com" target="_blank"><img width="250" height="120" src="https://www.nerves-project.org/hubfs/black.svg"></a>

<a href="https://www.binarynoggin.com" target="_blank"><img width="250" src="https://www.nerves-project.org/assets/BinaryNoggin_logo_250.png"></a>

[[Become a metal level sponsor]](http://nerves-project.org/sponsors)

## OpenCollective Backers

Thank you to all our monetary backers! Hardware costs money and without support,
we wouldn't be able to support nearly as many devices. 🙏 [[Become a
backer](https://opencollective.com/nerves-project#backer)]

<a href="https://opencollective.com/nerves-project#backers" target="_blank"><img src="https://opencollective.com/nerves-project/backers.svg?width=890"></a>

## OpenCollective Sponsors

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

Copyright (C) 2015-2021 by the Nerves Project developers <nerves@nerves-project.org>
