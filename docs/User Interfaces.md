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

#### Using a poncho project structure

First, we generate the two new Mix projects in a containing directory:

```bash
mkdir my_app && cd my_app
mix nerves.new my_app_firmware
mix phx.new my_app_ui --no-ecto --no-webpack
```

Now, we add the Phoenix-based `my_app_ui` project to the `my_app_firmware`
project as a dependency, because we want to use the `my_app_firmware` project
as a deployment wrapper around the `my_app_ui` project.

```elixir
# my_app_firmware/mix.exs

# ...
  defp deps do
    [
      # Dependencies for all targets
      {:my_app_ui, path: "../my_app_ui"},
      {:nerves, "~> 1.4", runtime: false},
      # ...
    ]
  end
# ...
```

If we're using the poncho project structure, we can skip ahead to the section
where we [configure networking](#configure-networking).

#### Using an umbrella project structure

If we would rather use the umbrella project structure instead, we can do so as follows:

```bash
mix new my_app --umbrella
cd my_app/apps
mix nerves.new my_app_firmware
mix phx.new my_app_ui --no-ecto --no-webpack
```

Then, we add the Phoenix `my_app_ui` project to the `my_app_firmware` project
as a dependency using the `in_umbrella` option instead of the `path` option:

```elixir
# apps/my_app_firmware/mix.exs

# ...
  defp deps do
    [
      # Dependencies for all targets
      {:my_app_ui, in_umbrella: true},
      {:nerves, "~> 1.4", runtime: false},
      # ...
    ]
  end
# ...
```

##### Specifying configuration order

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

By default, the `my_app_firmware` project will include the `nerves_init_gadget`
dependency, which simplifies the network setup and configuration process. The
default configuration assumes that we will be using a target device that
supports USB gadget devices (such as the Raspberry Pi Zero and Rapsberry Pi 3
A+). It configures the virtual Ethernet interface `usb0` to connect to the host
computer over a USB cable by running a simple DHCP server on the device.

If you want to use some other network configuration, such as wired or wireless
Ethernet, please refer to the [`nerves_init_gadget` documentation] and the
underlying [`nerves_network` documentation] as needed.

[`nerves_init_gadget` documentation]: https://hexdocs.pm/nerves_init_gadget
[`nerves_network` documentation]: https://hexdocs.pm/nerves_network

```elixir
# my_app_firmware/config/config.exs

config :nerves_init_gadget,
  ifname: "usb0",
  address_method: :dhcpd,
  mdns_domain: "nerves.local",
  node_name: node_name,
  node_host: :mdns_domain
```

### Configure Phoenix

In order to deploy the `my_app_ui` Phoenix-based project along with the
Nerves-based `my_app_firmware` project, we need to configure our Phoenix
`Endpoint` using appropriate settings for deployment on an emdedded device.  If
we're using a poncho project structure, we'll need to keep in mind that the
`my_app_ui` configuration won't be applied automatically, so we should either
`import` it from there or duplicate the required configuration.

Assuming that we're using the poncho project structure, our configuration might
look like this:

```elixir
# my_app_firmware/config/config.exs

use Mix.Config

# When we deploy to a device, we use the "prod" configuration:
import_config "../../my_app_ui/config/config.exs"
import_config "../../my_app_ui/config/prod.exs"

config :my_app_ui, MyAppUiWeb.Endpoint,
  # Nerves root filesystem is read-only, so disable the code reloader
  code_reloader: false,
  http: [port: 80],
  # Use compile-time Mix config instead of runtime environment variables
  load_from_system_env: false,
  # Start the server since we're running in a release instead of through `mix`
  server: true,
  url: [host: "nerves.local", port: 80],
```

There we have it! A Phoenix-based web application is now ready to run on our
Nerves-based embedded device. By separating the Phoenix-based project from the
Nerves-based project, we enable teams to work on the core functionality and
user interface code even without having physical hardware. We also minimize the
hardware/software integration effort by managing both the core software and the
firmware deployment infrastructure in a single poncho or umbrella project.

When developing the UI, we can simply run the Phoenix server from the
`my_app_ui` project directory:

```bash
cd path/to/ui
iex -S mix phx.server
```

When it's time to deploy firmware to our hardware, we can do it from the
`my_app_firmware` project directory:

```bash
cd my_app_firmware
export MIX_TARGET=rpi3
mix deps.get
mix firmware
# (Connect the SD card)
mix firmware.burn
```
