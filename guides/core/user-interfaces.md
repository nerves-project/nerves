# User Interfaces

## Phoenix web interface

The [Phoenix] web framework makes an excellent companion to [Nerves]-based devices
that need to serve content over HTTP directly from the device. For example, a
device with no display might provide administration and configuration
interfaces intended to be accessed from a computer or mobile device.
[Hello Phoenix] is an example of structuring a project as described here.

[Nerves]: https://www.nerves-project.org/
[Phoenix]: http://www.phoenixframework.org/
[Hello Phoenix]: https://github.com/nerves-project/nerves_examples/tree/main/hello_phoenix

### Choosing a project structure

There are two commonly used project structures for Nerves-based devices that uses
Phoenix web interface:

- [poncho project structure]
- [umbrella project structure]

Although Nerves supports both, the preferred project structure is what we call
poncho project structure. For the reasoning behind this, please see the original
[blog post describing poncho projects]. The following steps assume that we use
the poncho project structure.

Using the poncho project structure, we simply use separate [Mix projects],
side-by-side with path dependencies between them, in the same source code repository.

[blog post describing poncho projects]: https://embedded-elixir.com/post/2017-05-19-poncho-projects/
[poncho project structure]: http://embedded-elixir.com/post/2017-05-19-poncho-projects/
[umbrella project structure]: https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-projects.html
[Mix projects]: https://hexdocs.pm/mix/Mix.html

### Create a poncho project

First, we generate the two new Mix projects in a containing directory:

```bash
# Create a container directory called "my_app"
mkdir my_app && cd my_app

# Create a Nerves firmware project called "my_app_firmware"
mix nerves.new my_app_firmware

# Create a Phoenix 1.6 UI project called "my_app_ui", without Ecto or Swoosh Mailer
mix phx.new my_app_ui --no-ecto --no-mailer
```

Now, we add the Phoenix-based `my_app_ui` project to the `my_app_firmware`
project as a dependency, because we want to use the `my_app_firmware` project
as a deployment wrapper around the `my_app_ui` project.

```elixir
# my_app/my_app_firmware/mix.exs

# ...
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.7.0", runtime: false},
      # ...
      {:my_app_ui, path: "../my_app_ui", targets: @all_targets, env: Mix.env()},
      # ...
    ]
  end
# ...
```

We need a few adjustments to the UI project's `mix.exs`.  By default when `MIX_ENV`
is `dev`, the default Phoenix setup runs:
- `phoenix_live_reload` to reload code changes
- [`esbuild`] to rebuild assets as needed
- `tailwindcss` to optimize css (Phoenix 1.7+)

This doesn't work on target device, so we need to limit it to only run on the
host:

```elixir
# my_app/my_app_ui/mix.exs

  defp deps do
    [
      {:phoenix, "~> 1.6.0"},
      # ...
      {:phoenix_live_reload, "~> 1.2", only: :dev, targets: [:host]},
      # ...
      {:esbuild, "~> 0.5", runtime: Mix.env() == :dev && Mix.target() == :host},
      {:tailwind, "~> 0.1.8", runtime: Mix.env() == :dev && Mix.target() == :host},
      # ...
    ]
  end
```

[`esbuild`]: https://hexdocs.pm/esbuild/Esbuild.html

### Configure networking

Refer to the [Connecting to a Nerves Target page](connecting-to-a-nerves-target.html).

### Configure Phoenix

In order to deploy the `my_app/my_app_ui` Phoenix-based project along with the
Nerves-based `my_app/my_app_firmware` project, we need to configure our [`Phoenix.Endpoint`]
using appropriate settings for deployment on an embedded device. If
we're using a poncho project structure, we'll need to keep in mind that the
`my_app/my_app_ui` configuration won't be applied automatically, so we should either
`import` it from there or duplicate the required configuration.

Our configuration might look like this (as of Phoenix 1.6.2):

```elixir
# my_app_/my_app_firmware/config/target.exs

config :my_app_ui, MyAppUiWeb.Endpoint,
  url: [host: "nerves.local"],
  http: [port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json",
  secret_key_base: "HEY05EB1dFVSu6KykKHuS4rQPQzSHv4F7mGVB/gnDLrIu75wE/ytBXy2TaL3A6RA",
  live_view: [signing_salt: "AAAABjEyERMkxgDh"],
  check_origin: false,
  render_errors: [view: MyAppUiWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Ui.PubSub,
  # Start the server since we're running in a release instead of through `mix`
  server: true,
  # Nerves root filesystem is read-only, so disable the code reloader
  code_reloader: false

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason
```

Note that this minimal configuration corresponds to our freshly generated
phoenix application without Ecto or Swoosh as we passed the `--no-ecto` and
`--no-mailer` flags to the generator earlier. If you wish to use those features,
remember to add the relevant configuration. An example for Ecto can be seen
in the [Nerves + Phoenix example](https://github.com/nerves-project/nerves_examples/blob/1da4597bee5d9f26c643cb32523fc70e136d1e2b/hello_phoenix/firmware/config/target.exs#L17).

There we have it! A Phoenix-based web application is now ready to run on our
Nerves-based embedded device. By separating the Phoenix-based project from the
Nerves-based project, we enable teams to work on the core functionality and
user interface code even without having physical hardware. We also minimize the
hardware/software integration effort by managing both the core software and the
firmware deployment infrastructure in a single poncho project.

[`Phoenix.Endpoint`]: https://hexdocs.pm/phoenix/Phoenix.Endpoint.html

### Develop the UI

When developing the UI, we can simply run the Phoenix server from the
`my_app_ui` project directory:

```bash
cd path/to/my_app_ui
iex -S mix phx.server
```

### Deploy the firmware

First we build our assets in the `my_app_ui` project directory and prepare them
for deployment to the firmware:

```bash
cd path/to/my_app_ui

# We want to build assets on our host machine.
export MIX_TARGET=host
export MIX_ENV=dev

# This needs to be repeated when you change dependencies for the UI.
mix deps.get

# This needs to be repeated when you change JS or CSS files.
mix assets.deploy
```

When it's time to deploy firmware to our hardware, we can do it from the
`my_app_firmware` project directory:

```bash
cd path/to/my_app_firmware

# Specify our target device.
export MIX_TARGET=rpi3
export MIX_ENV=dev

mix deps.get
mix firmware
# (Connect the SD card)
mix firmware.burn
```

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

## eInk displays

Some initial work has been done to support eInk displays like the Pimoroni Inky
[pHAT](https://shop.pimoroni.com/products/inky-phat) and
[wHAT](https://shop.pimoroni.com/products/inky-what) models. Look at the
[`:inky` repo](https://github.com/pappersverk/inky) for more info.

## OLED

Basic work has been done to support small OLED screens with the SSD1306 chip which
are usually smaller screens a few inches wide. More info in the [`:oled` docs](https://hexdocs.pm/oled)

## Web Kiosks

Several companies have integrated web browsers with Nerves for kiosk applications.
Unfortunately, public repositories are currently unmaintained. If this is of interest to
you, take a look at the repos in the [Nerves Web Kiosks](https://github.com/nerves-web-kiosk)
org and consider helping maintain them.
