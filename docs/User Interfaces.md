# User Interfaces

## Phoenix web interfaces

The Phoenix web framework makes an excellent companion to Nerves-based devices
that need to serve content over HTTP directly from the device. For example, a
device with no display might provide administration and configuration
interfaces intended to be accessed from a computer or mobile device.

### Choosing a project structure

Although Nerves supports umbrella projects, the preferred project structure is
to simply use separate Mix projects, side-by-side with path dependencies
between them, in the same source code repository. We call this a "poncho
project" structure. For the reasoning behind this, please see the original
[blog post describing poncho projects].

[blog post describing poncho projects]: https://embedded-elixir.com/post/2017-05-19-poncho-projects/

### Using a poncho project structure

First, we generate the two new Mix projects in a containing directory:

```bash
mkdir my_app && cd my_app
mix nerves.new my_app_firmware
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
      {:nerves, "~> 1.7", runtime: false},
      # ...
      {:my_app_ui, path: "../my_app_ui", targets: @all_targets, env: Mix.env()},
      # ...
    ]
  end
# ...
```

If we're using the poncho project structure, we can skip ahead to the section
where we [configure networking](#configure-networking).

### Using an umbrella project structure

If we would rather use the umbrella project structure instead, we can do so as follows:

```bash
mix new my_app --umbrella
cd my_app/apps
mix nerves.new my_app_firmware
mix phx.new my_app_ui --no-ecto --no-mailer
```

Then, we add the Phoenix `my_app_ui` project to the `my_app_firmware` project
as a dependency using the `in_umbrella` option instead of the `path` option:

```elixir
# apps/my_app_firmware/mix.exs

# ...
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.7", runtime: false},
      # ...
      {:my_app_ui, in_umbrella: true, targets: @all_targets, env: Mix.env()},
      # ...
    ]
  end
# ...
```
#### Specifying configuration order

By default when you use the umbrella project style, the top-level configuration
loads the sub-project configurations in lexicographic order:

```elixir
# my_app/config/config.exs

use Mix.Config

import_config "../apps/*/config/config.exs"
```

This can cause problems, depending on the names of your sub-projects, because
it is likely that we will want to override certain device-specific settings in
the `my_app_firmware` config. We can solve this by specifying the order in
which the config files get imported:

```elixir
# my_app/config/config.exs

use Mix.Config

import_config "../apps/my_app_ui/config/config.exs"
import_config "../apps/my_app_firmware/config/config.exs"
```

### Configure networking

By default, the `my_app_firmware` project will include the [`nerves_pack`]
dependency, which simplifies the network setup and configuration process. At
runtime, `nerves_pack` will detect all available interfaces that have not been
configured and apply defaults for `usb*` and `eth*` interfaces.

For `eth*` interfaces, the device attempts to connect to the network
with DHCP using `ipv4` addressing.

For `usb*` interfaces, it uses [`vintage_net_direct`](https://hexdocs.pm/vintage_net_direct/VintageNetDirect.html) to run a simple DHCP server
on the device and assign the host an IP address over a USB cable.

If you want to use some other network configuration, such as wired or wireless
Ethernet, please refer to the [`nerves_pack` documentation](https://hexdocs.pm/nerves_pack/readme.html) and the
underlying [`vintage_net` documentation](https://hexdocs.pm/vintage_net/VintageNet.html) as needed.

[`nerves_pack`]: https://hexdocs.pm/nerves_pack
[`VintageNetWifi`]: https://hexdocs.pm/vintage_net_wifi
[`VintageNetEthernet`]: https://hexdocs.pm/vintage_net_ethernet
[`VintageNetDirect`]: https://hexdocs.pm/vintage_net_direct
[`VintageNetMobile`]: https://hexdocs.pm/vintage_net_mobile

### Configure Phoenix

In order to deploy the `my_app_ui` Phoenix-based project along with the
Nerves-based `my_app_firmware` project, we need to configure our Phoenix
`Endpoint` using appropriate settings for deployment on an embedded device. If
we're using a poncho project structure, we'll need to keep in mind that the
`my_app_ui` configuration won't be applied automatically, so we should either
`import` it from there or duplicate the required configuration.

Assuming that we're using the poncho project structure, our configuration might
look like this:

```elixir
# my_app_firmware/config/target.exs

import Config

# as of phoenix 1.6.2
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

There we have it! A Phoenix-based web application is now ready to run on our
Nerves-based embedded device. By separating the Phoenix-based project from the
Nerves-based project, we enable teams to work on the core functionality and
user interface code even without having physical hardware. We also minimize the
hardware/software integration effort by managing both the core software and the
firmware deployment infrastructure in a single poncho or umbrella project.

### Develop the UI

When developing the UI, we can simply run the Phoenix server from the
`my_app_ui` project directory:

```bash
cd path/to/my_app_ui
iex -S mix phx.server
```

### Deploy the firmware

First we build our assets in the `my_app_ui` project directory and prepare them for deployment to the firmware:

```bash
cd path/to/my_app_ui

# This needs to be repeated when you change dependencies for the UI.
mix deps.get

# This needs to be repeated when you change JS or CSS files.
mix assets.deploy
```

When it's time to deploy firmware to our hardware, we can do it from the `my_app_firmware` project directory:

```bash
cd path/to/my_app_firmware
export MIX_TARGET=rpi3
mix deps.get
mix firmware
# (Connect the SD card)
mix firmware.burn
```
