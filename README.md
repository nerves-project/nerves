# Nerves
Craft and deploy bulletproof embedded software in Elixir

[![Build Status](https://travis-ci.org/nerves-project/nerves.svg?branch=master)](https://travis-ci.org/nerves-project/nerves)

## Requirements

* 64-bit host
* Mac OS 10.10+
* Linux (tested on Debian / Ubuntu / Redhat / CentOS)
* Windows 10 with [Windows Subsystem for Linux](https://msdn.microsoft.com/en-us/commandline/wsl/install_guide) (untested)
* Elixir ~> 1.4
* [fwup](https://github.com/fhunleth/fwup) >= 0.8.0

## Quick-Reference

### Generating a New Nerves Application

```bash
$ mix nerves.new my_app
```

### Building Firmware

```bash
$ export MIX_TARGET=rpi3
$ mix deps.get      # Fetch the dependencies
$ mix firmware      # Cross-compile dependencies and create a .fw file
$ mix firmware.burn # Burn firmware to an inserted SD card
```

## Docs

[Installation Docs](https://hexdocs.pm/nerves/installation.html)

[Getting Started](https://hexdocs.pm/nerves/getting-started.html)

[Frequently-Asked Questions](https://hexdocs.pm/nerves/faq.html)

[Systems](https://hexdocs.pm/nerves/systems.html)

[Targets](https://hexdocs.pm/nerves/targets.html)

[User Interfaces](https://hexdocs.pm/nerves/user-interfaces.html)

[Advanced Configuration](https://hexdocs.pm/nerves/advanced-configuration.html)

Copyright (C) 2015-2017 by the Nerves Project developers <nerves@nerves-project.org>
