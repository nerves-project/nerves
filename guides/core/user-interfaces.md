<!--
  SPDX-FileCopyrightText: 2016 Justin Schneck
  SPDX-FileCopyrightText: 2019 Greg Mefford
  SPDX-FileCopyrightText: 2021 Masatoshi Nishiguchi
  SPDX-FileCopyrightText: 2022 Jon Carstens
  SPDX-FileCopyrightText: 2024 Christoph Lupprich
  SPDX-FileCopyrightText: 2024 Lars Wikman
  SPDX-FileCopyrightText: 2025 Frank Hunleth
  SPDX-License-Identifier: CC-BY-4.0
-->
# User Interfaces

## Phoenix web interface

The [Phoenix] web framework makes an excellent companion to [Nerves]-based devices
that need to serve content over HTTP directly from the device. For example, a
device with no display might provide administration and configuration
interfaces intended to be accessed from a computer or mobile device.

Phoenix can also be used for systems with a built-in display or connected to a
display. This is commonly done for kiosks or digital signage. For this the
Nerves system itself needs the ability to show the browser. The
[Nerves Web Kiosks] systems can do this.

LiveView does very well in local network embedded setups as there is usually no
significant latency to the server (the device) and it gives you a lot of tools
for building out UI.

To get started with a project combining Nerves and Phoenix the
[Hello LiveView] example is recommended. There are many approaches to setting
up a combined Nerves and Phoenix project as Nerves and Phoenix are both really
just Elixir projects.

In the past this guide addressed both umbrellas and ponchos. Those are advanced
topics. This is all a starting point and the example project is a better place
to begin.

[Nerves]: https://www.nerves-project.org/
[Phoenix]: http://www.phoenixframework.org/
[Hello LiveView]: https://github.com/nerves-project/nerves_examples/tree/main/hello_live_view

## Scenic

Scenic is 2D UI framework written in Elixir that's designed with
embedded systems in mind and works well with Nerves on screens like the
[Raspberry Pi Touch Display](https://www.raspberrypi.com/products/raspberry-pi-touch-display/)
or HDMI connected screens.

Helpful links:
* [Scenic: Getting Start with Nerves doc](https://scenic.hexdocs.pm/getting_started_nerves.html)
* [Scenic Forum](https://elixirforum.com/c/elixir-framework-forums/scenic-forum/107)
* [ElixirConf 2018 - Introducing Scenic A Functional UI Framework - Boyd Multerer](https://www.youtube.com/watch?v=1QNxLNMq3Uw)
* [Scenic Now and Looking Ahead - Boyd Multerer | ElixirConfEU Virtual 20](https://www.youtube.com/watch?v=tej-SyhZrqk)

## Web Kiosk

As mentioned in the Phoenix section. You can also run a basic web browser and
produce a UI using common web technologies. There are currently maintained
[Nerves Web Kiosks] for RPi4 and RPi5 using Cog which is a small embeddable
browser.

## Flutter

Many companies have had success with implementing their UI in Flutter. See
the [Nerves Flutter Support project](https://github.com/nerves-flutter/nerves_flutter_support) for one implementation.

## Emerge UI

Emerge is a new Elixir UI framework that provides a declarative UI. It works
well with Nerves. See the [Emerge project](https://github.com/emerge-elixir/emerge) for details.

## Erlang Graphics Drawer

If your drawing needs are very simple, the venerable EGD may suffice. The
original library on the OTP team's GitHub organization is unmaintained, so
see a more recently maintained [fork on Hex.pm](https://hex.pm/packages?search=egd&sort=recent_downloads).

[Nerves Web Kiosks]: https://github.com/nerves-web-kiosk