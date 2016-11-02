# User Interfaces

## Phoenix Web Interfaces

Phoenix makes an excellent companion to Nerves applications by offering an easy-to-use, powerful framework to create user interfaces in parallel with Nerves device code. The easiest way to handle this is to layout your application as an Umbrella. Lets get started...

First, generate a new umbrella app, called `nervy` in this case:

```
$ mix new nervy --umbrella
```

Next, create your sub-applications for Nerves and for Phoenix:

```
$ cd nervy/apps
$ mix nerves.new fw --target rpi3
...
$ mix phoenix.new ui --no-ecto --no-brunch
...
```

Now, add the Phoenix `ui` app and the `nerves_networking` library to the `fw` app as dependencies:

```elixir
# nervy/apps/fw/mix.exs

...
defp deps do
  [{:ui, in_umbrella: true},
   {:nerves_networking, github: "nerves-project/nerves_networking"}]
end
...
```

and remember to add them to the OTP-configuration in the `fw` app:

```elixir
# nervy/apps/fw/mix.exs

...
applications: [:logger,
               :ui,
               :nerves_networking]]
...
```

And in order to start networking when the fw boots add a child worker that sets up networking. This example sets up the networking using DHCP. For more network settings check the `nerves_networking` project.

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

config :logger, level: :debug
```

There you have it! A Phoenix web application ready for your Nerves device. By separating the Phoenix application from the Nerves application, you can distribute the development between resources and continue to leverage the features we have all come to love from Phoenix, like live code reloading.

When developing your UI, you can simply run the phoenix server from the UI application:

```
# nervy/apps/ui
$ mix phoenix.server
```

When it's time to create your firmware:
```
# nervy/apps/fw
$ mix deps.get
$ mix firmware

# and in order to burn it
$ mix firmware.burn
```

__Note__: You will need to have the latest version of rebar installed in order for `mix firmware` to work because we are using features that aren't included in the older releases. If you encounter an error that stating `unrecognized command line option '-flat_namespace'` then you can use the following command to install a later version of rebar which should get you past this error.
```
mix local.rebar
```
