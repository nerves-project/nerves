<!--
  SPDX-FileCopyrightText: 2025 Marc Lainez
  SPDX-License-Identifier: CC-BY-4.0
-->
# Hardware Interfaces

## Elixir Circuits

Dreaming of blinking LEDs or powering on some small DC motor with some Elixir magic?
Then you should use [Elixir circuits](https://elixir-circuits.github.io/). It provides different interfaces to communicate with hardware devices connected to your target.

There is a [quickstart guide](https://github.com/elixir-circuits/circuits_quickstart) you can follow to get started in no time.

[Circuits GPIO](https://hexdocs.pm/circuits_gpio) has a great documentation if you want to use your own firmware and not use Livebook.

As mentioned in the [Example projects](./getting-started.html#example-projects) section, you can find several examples on how to get started with hardware projects such as:
- [Blinky](https://github.com/nerves-project/nerves_examples/tree/main/blinky), showing you how to blink the onboard LED.
- [Hello GPIO](https://github.com/nerves-project/nerves_examples/tree/main/hello_gpio), which will use an LED connected to a GPIO Pin, and a manual switch on another one.

These two examples are great ways to get started with electronics on Nerves.