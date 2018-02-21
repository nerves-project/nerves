# User Interfaces

## Phoenix Web Interfaces

Phoenix makes an excellent companion to Nerves applications by offering an easy-to-use, powerful framework to create user interfaces in parallel with Nerves device code.

### Choosing a project structure

Although Nerves supports umbrella projects, the preferred project structure is to simply use separate Mix projects side-by-side with path dependencies between them if they're in the same source code repository. We call this a "poncho project" structure. For the reasoning behind this, please see [this blog post describing poncho projects](http://embedded-elixir.com/post/2017-05-19-poncho-projects/).

#### Using a poncho project structure

First, generate the two new apps in a containing folder:

```bash
$ mkdir nervy && cd nervy
$ mix nerves.new fw
$ mix phx.new ui --no-ecto --no-brunch
```

Now, add the Phoenix `ui` app and the `nerves_network` library to the `fw` app as dependencies:

```elixir
# fw/mix.exs

# ...
def deps do
  [{:nerves_network, "~> 0.3"},
   {:ui, path: "../ui"}]
end
# ...
```

Next: [Configure Networking](#configure-networking)


#### Using an umbrella project structure

First, generate a new umbrella app, called `nervy` in this case:

```bash
$ mix new nervy --umbrella
```

Next, create your sub-applications for Nerves and for Phoenix:

```bash
$ cd nervy/apps
$ mix nerves.new fw
$ mix phx.new ui --no-ecto --no-brunch
```

Now, add the Phoenix `ui` app and the `nerves_network` library to the `fw` app as dependencies:

```elixir
# apps/fw/mix.exs

# ...
def deps do
  [{:ui, in_umbrella: true},
   {:nerves_network, "~> 0.3"}]
end
# ...
```

##### Specifying configuration order

By default, the top-level configuration loads the application configurations in an unordered way:

```elixir
import_config "../apps/*/config/config.exs"
```

This can cause problems if the  `ui` config is applied last: we may lose overrides applied in the `fw` config. You need to force the order in which the config files get imported:

```elixir
# config/config.exs

use Mix.Config

import_config "../apps/ui/config/config.exs"
import_config "../apps/fw/config/config.exs"
```


### Configure networking

#### Nerves version < 0.9
In order to start the network when `fw` boots, add `nerves_network` to the `bootloader` configuration in `config.exs`.

```elixir
# fw/config/config.exs

# ...
config :bootloader,
  init: [:nerves_runtime, :nerves_network]
# ...
```

#### Nerves version >= 0.9

In version `0.9` `bootloader` was replaced with `shoehorn` and you need to use it's section in `config.exs`:

```elixir
# fw/config/config.exs

# ...
config :shoehorn,
   init: [:nerves_runtime, :nerves_network],
   app: Mix.Project.config()[:app]
# ...
```

To set the default networking configuration:

```elixir
# fw/config/config.exs

# ...

# For WiFi, set regulatory domain to avoid restrictive default
config :nerves_network,
  regulatory_domain: "US"

config :nerves_network, :default,
  wlan0: [
    ssid: System.get_env("NERVES_NETWORK_SSID"),
    psk: System.get_env("NERVES_NETWORK_PSK"),
    key_mgmt: String.to_atom(System.get_env("NERVES_NETWORK_MGMT"))
  ],
  eth0: [
    ipv4_address_method: :dhcp
  ]

# ...
```

For more network settings, see the [`nerves_network`](https://github.com/nerves-project/nerves_network) project.


### Configure Phoenix

In order to build the `ui` Phoenix app into the Nerves `fw` app, you will need to make some changes to your `fw` application configuration:

```elixir
# fw/config/config.exs

# ...
config :ui, UiWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 80],
  secret_key_base: "#############################",
  root: Path.dirname(__DIR__),
  server: true,
  render_errors: [view: UiWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Nerves.PubSub, adapter: Phoenix.PubSub.PG2],
  code_reloader: false

config :logger, level: :debug
# ...
```


There you have it!
A Phoenix web application ready to run on your Nerves device.
By separating the Phoenix application from the Nerves application, you could easily distribute the development between team members and continue to leverage the features we have all come to love from Phoenix, like live code reloading.

When developing your UI, you can simply run the Phoenix server from the UI application:

```bash
$ cd path/to/ui
$ mix phoenix.server
```

When it's time to create your firmware:

```bash
$ cd path/to/fw
$ export MIX_TARGET=rpi3
$ mix deps.get
$ mix firmware
$ mix firmware.burn
```
