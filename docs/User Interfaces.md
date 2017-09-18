# User Interfaces

## Phoenix Web Interfaces

Phoenix makes an excellent companion to Nerves applications by offering an easy-to-use, powerful framework to create user interfaces in parallel with Nerves device code.

### Set up your application

Although it's possible to lay out your application as an Umbrella project, the preferred way is to use poncho projects, i.e. a side-by-side project layout. For the reasoning behind this, please read the [Poncho Projects](http://embedded-elixir.com/post/2017-05-19-poncho-projects/) blog post by Greg Mefford.

We'll cover the use of both approaches here, but we encourage you to use ponchos.

#### Using a poncho project layout

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


#### Using an umbrella project layout

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

By default, the main config loads the application configs in an unordered way: `import_config "../apps/*/config/config.exs`. This can cause problems if the  `ui` config is applied last: we may lose overrides applied in the `fw` config. You need to force the order in which the config files get imported:

```elixir
# nervy/config/config.exs

use Mix.Config

import_config "../apps/ui/config/config.exs"
import_config "../apps/fw/config/config.exs"
```


### Configure networking

In order to start the network when `fw` boots, add `nerves_network` to the `bootloader` configuration in `config.exs`.

```elixir
# fw/config/config.exs

# ...
config :bootloader,
  init: [:nerves_runtime, :nerves_network]
# ...
```

To set the default networking configuration:

```elixir
# fw/config/config.exs

# ...
# Use your ISO 3166-1 alpha-2 country code below

config :nerves_network,
  regulatory_domain: "US"

config :nerves_network, :default,
  eth0: [
    ipv4_address_method: :dhcp
  ]

# ...
```

For more network settings, see the [`nerves_network`](https://github.com/nerves-project/nerves_network) project.


### Configure Phoenix

In order to build the `ui` Phoenix app into the Nerves `fw` app, you need to add some configuration to your firmware config:

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
