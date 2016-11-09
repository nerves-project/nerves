# Nerves
Craft and deploy bulletproof embedded software in Elixir

[![Build Status](https://travis-ci.org/nerves-project/nerves.svg?branch=master)](https://travis-ci.org/nerves-project/nerves)

## Requirements

64-bit host running
* Mac OS 10.10+ or Linux (We've tested on Debian / Ubuntu / Redhat / CentOS)
* Elixir ~> 1.2.4 or ~> 1.3
* [fwup](https://github.com/fhunleth/fwup) >= 0.8.0

## Docs

[Installation Docs](https://hexdocs.pm/nerves/installation.html)

[Getting Started](https://hexdocs.pm/nerves/getting-started.html)

[Advanced Configuration](https://hexdocs.pm/nerves/advanced-configuration.html)

## Install

### Bootstrap Archive

Nerves is a suite of components which work together to create reproducible firmware using the Elixir programming language. To build Nerves applications on your machine, you will first be required to install the Nerves Bootstrap archive. The Nerves Bootstrap archive contains mix hooks required to bootstrap your mix environment to properly cross compile your application and dependency code for the Nerves target.

To install the archive:
```
$ mix archive.install https://github.com/nerves-project/archives/raw/master/nerves_bootstrap.ez
```
If the Nerves Bootstrap archive does not install properly, you can download the file from github directly and then install using the command `mix archive.install /path/to/local/nerves_bootstrap.ez`

In addition to the archive, you will need to include the `:nerves` application in your application deps and applications list.

  1. Add nerves to your list of dependencies in `mix.exs`:

        def deps do
          [{:nerves, "~> 0.3"}]
        end

  2. Ensure nerves is started before your application:

        def application do
          [applications: [:nerves]]
        end

Installing system specific dependencies:
  [Installation Docs](https://hexdocs.pm/nerves/installation.html)

## Project Configuration
You can generate a new nerves project using the project generator. You are required to pass a target tag to the generator. You can find more information about target tags for your board at  http://nerves-project.org

`mix nerves.new my_app --target rpi2`

### Building Firmware

Now that everything is installed and configured its time to make some firmware. Here is the workflow

`mix deps.get` - Fetch the dependencies.

`mix compile` - Bootstrap the Nerves Env and compile the App.

`mix firmware` - Creates a fw file

`mix firmware.burn` - Burn firmware to an inserted SD card.

Copyright (C) 2015-2016 by the Nerves Project developers <nerves@nerves-project.org>
