# Going further

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

## Elixir Circuits

Dreaming of blinking LEDs or powering on some small DC motor with some Elixir magic?
The you should use [Elixir circuits](https://elixir-circuits.github.io/). It provides different interfaces to communicate with hardware devices connected to your target.

If you want to quickly get started, there is a [quickstart guide](https://github.com/elixir-circuits/circuits_quickstart) you can follow to get started in no time.

[Circuits GPIO](https://hexdocs.pm/circuits_gpio) has a great documentation if you want to use your own firmware and now use Livebook.

As mentioned in the [Example projects](#example-projects) below, you can find several examples on how to get started with hardware with projects such as:
- [Blinky](https://github.com/nerves-project/nerves_examples/tree/main/blinky), showing you how to blink the onboard LED.
- [Hello GPIO](https://github.com/nerves-project/nerves_examples/tree/main/hello_gpio), which will use an LED connected to a GPIO Pin, and a manual switch onther one.

These two examples are great ways to get started with electronics on Nerves.

## Example projects

If you are interested in exploring other Nerve codebases and projects, you can
check out our [collection of example projects](https://github.com/nerves-project/nerves_examples).

Be sure to set your `MIX_TARGET` environment variable appropriately for the
target hardware you have. Visit the [Supported Targets Page](supported-targets.html) for more
information on what target name to use for the boards that Nerves supports.

The `nerves_examples` repository contains several example projects to get you
started.  The simplest example is Blinky, known as the "Hello World" of hardware
because all it does is blink an LED indefinitely.  If you are ever curious about
project structuring or can't get something running, check out Blinky and run it
on your target to confirm that it works in the simplest case.

```bash
git clone https://github.com/nerves-project/nerves_examples
export MIX_TARGET=rpi0
cd nerves_examples/blinky
mix do deps.get, firmware, firmware.burn
```

## Community links

Do not hesitate to seek for help if you feel stuck at any point during your journey with Nerves. 

- [Elixir Slack #nerves channel](https://elixir-slack.community/)
- [Elixir Discord #nerves channel](https://discord.gg/elixir)
- [Nerves Forum](https://elixirforum.com/c/elixir-framework-forums/nerves-forum/74)
- [Nerves Meetup](https://www.meetup.com/nerves)
- [Nerves Newsletter](https://underjord.io/nerves-newsletter.html)