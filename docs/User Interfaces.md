# User Interfaces

## Phoenix Web Interfaces

Phoenix makes an excellent companion to Nerves applications by offering an easy-to-use, powerful framework to create user interfaces in parallel with Nerves device code.
The easiest way to handle this is to lay out your application as an Umbrella.

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
# nervy/apps/fw/mix.exs

...
def deps do
  [{:ui, in_umbrella: true},
   {:nerves_network, "~> 0.3"}]
end
...
```

In order to start the network when `fw` boots, add `nerves_network` to the `bootloader` configuration in `config.exs`.

```elixir
config :bootloader,
  init: [:nerves_runtime, :nerves_network]
```

To set the default networking configuration:

```elixir
config :nerves_network, :default,
  eth0: [
    ipv4_address_method: :dhcp
  ]
```

For more network settings, see the [`nerves_network`](https://github.com/nerves-project/nerves_network) project.


In order to build the `ui` Phoenix application into the nerves `fw` app, you need to add some configuration to your firmware config:

```elixir
# nervy/apps/fw/config/config.exs

use Mix.Config

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
```

By default,
the main config loads the application configs in an unordered way: `import_config "../apps/*/config/config.exs`.   This can cause problems if the  `ui` config is applied last: we loose the overrides we just added in the previous step.  You need to force the order in which the config files get imported:

```elixir
# nervy/config/config.exs

use Mix.Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
import_config "../apps/ui/config/config.exs"
import_config "../apps/fw/config/config.exs"
```

There you have it!
A Phoenix web application ready to run on your Nerves device.
By separating the Phoenix application from the Nerves application, you could easily distribute the development between team members and continue to leverage the features we have all come to love from Phoenix, like live code reloading.

When developing your UI, you can simply run the phoenix server from the UI application:

```bash
$ cd nervy/apps/ui
$ mix phoenix.server
```

When it's time to create your firmware:

```bash
$ cd nervy/apps/fw
$ export MIX_TARGET=rpi3
$ mix deps.get
$ mix firmware
$ mix firmware.burn
```
