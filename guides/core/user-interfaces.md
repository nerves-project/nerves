# User Interfaces

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