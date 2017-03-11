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
$ mix phoenix.new ui --no-ecto --no-brunch
```

Now, add the Phoenix `ui` app and the `nerves_networking` library to the `fw` app as dependencies:

```elixir
# nervy/apps/fw/mix.exs

...
defp deps do
  [{:ui, in_umbrella: true},
   {:nerves_networking, "~> 0.6.0"}]
end
...
```

In order to start networking when `fw` boots, add a worker that sets up networking.
This example sets up the networking using DHCP.
For more network settings, check the [`nerves_networking` project](https://github.com/nerves-project/nerves_networking).

```elixir
# nervy/apps/fw/lib/fw.ex

...
# add networking
children = [
  worker(Task, [fn -> Nerves.Networking.setup :eth0, [mode: "dhcp"] end], restart: :transient)
]
...
```

In order to build the `ui` Phoenix application into the nerves `fw` app, you need to add some configuration to your firmware config:

```elixir
# nervy/apps/fw/config/config.exs

use Mix.Config

config :ui, Ui.Endpoint,
  http: [port: 80],
  url: [host: "localhost", port: 80],
  secret_key_base: "#############################",
  root: Path.dirname(__DIR__),
  server: true,
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Nerves.PubSub]
  pubsub: [name: Nerves.PubSub],
  code_reload: false

config :logger, level: :debug
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

