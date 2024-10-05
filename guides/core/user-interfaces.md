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
[Hello LiveView example] is recommended. There are many approaches to setting
up a combined Nerves and Phoenix project as Nerves and Phoenix are both really
just Elixir projects.

In the past this guide addressed both umbrellas and ponchos. Those are advanced
topics. This is all a starting point and the example project is a better place
to begin.

[Nerves]: https://www.nerves-project.org/
[Phoenix]: http://www.phoenixframework.org/
[Hello LiveView]: https://github.com/nerves-project/nerves_examples/tree/main/hello_liveview

## Scenic

Scenic is 2D UI framework written in Elixir that's designed with
embedded systems in mind and works well with Nerves on screens like the
[Raspberry Pi Touch Display](https://www.raspberrypi.com/products/raspberry-pi-touch-display/)
or HDMI connected screens.

Helpful links:
* [Scenic: Getting Start with Nerves doc](https://hexdocs.pm/scenic/getting_started_nerves.html)
* [Scenic Forum](https://elixirforum.com/c/elixir-framework-forums/scenic-forum/107)
* [ElixirConf 2018 - Introducing Scenic A Functional UI Framework - Boyd Multerer](https://www.youtube.com/watch?v=1QNxLNMq3Uw)
* [Scenic Now and Looking Ahead - Boyd Multerer | ElixirConfEU Virtual 20](https://www.youtube.com/watch?v=tej-SyhZrqk)

## Kiosk

As mentioned in the Phoenix section. You can also run a basic web browser and
produce a UI using common web technologies. There are currently maintained
[Nerves Web Kiosks] for RPi4 and RPi5 using Cog which is a small embeddable
browser and Weston which is a Wayland compositor to show it on.

## eInk displays

Some initial work has been done to support eInk displays like the Pimoroni Inky
[pHAT](https://shop.pimoroni.com/products/inky-phat) and
[wHAT](https://shop.pimoroni.com/products/inky-what) models. Look at the
[`:inky` repo](https://github.com/pappersverk/inky) for more info.

## OLED

Basic work has been done to support small OLED screens with the SSD1306 chip which
are usually smaller screens a few inches wide. More info in the [`:oled` docs](https://hexdocs.pm/oled)

[Nerves Web Kiosks]: https://github.com/nerves-web-kiosk