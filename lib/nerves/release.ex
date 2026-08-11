# SPDX-FileCopyrightText: 2019 Justin Schneck
# SPDX-FileCopyrightText: 2023 Jon Carstens
# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Release do
  @moduledoc """
  Nerves 1.x mix release integration

  This modules provides the Nerves integration with Mix releases for projects
  using Nerves 1.x callbacks. If you have a new project, you probably won't
  need to read this.

  ## Usage

  Your current project probably has references to this module in your
  `mix.exs`. Here's what updated projects should look like:

  ```
  def release do
    [
      ...
      include_erts: &Nerves.erts/0,
      steps: [&Nerves.init_release/1, :assemble],
      ...
    ]
  end
  ```

  While this just looks like two functions moved to the top level `Nerves`
  module, making this change has the side effect of removing the Nerves 1.x
  Shoehorn hook insertion. Your firmware will likely still work without
  completing the Shoehorn migration, but please complete it to avoid future
  confusion.

  ## Migration from Shoehorn

  One of Shoehorn's features was to make release startup deterministic between
  firmware builds by sorting OTP application loads and starts alphabetically
  when no other dependency forced an ordering. Shoehorn also set OTP apps as
  `:temporary` so that application crashes wouldn't exit the Erlang VM and
  reboot. Both of these features are handled by Nerves now via the
  `Nerves.BuildAction.BootOrder` and `Nerves.BuildAction.AppModes` build
  actions.

  Most projects will only need to make the following update to their
  `config/target.exs`:

  ```
  # Before
  config :shoehorn, init: [:nerves_runtime, :nerves_pack]

  # After
  config :nerves, application_sort: [init: [:nerves_runtime, :nerves_pack]]
  ```

  See [Nerves.BuildAction.SortApps] for documentation on these config entries.

  If this is your only use of Shoehorn (likely), remove `:shoehorn` from your
  Mix dependency list.

  Internally, your OTP release start script will be `start.boot` now rather
  than `shoehorn.boot`.  Erlinit is good about figuring this out as it will
  fall back to `start.boot` even when told to use `shoehorn.boot` if that file
  is missing. If you've created a custom Nerves system, you'll likely have at
  least one reference to `shoehorn.boot` that can be cleaned up.
  """

  alias Nerves.MixUtils

  @doc """
  Backwards compatible Nerves 1.x release

  This is the legacy entry point. It configures the release for embedded use
  and delegates to `Shoehorn.Release.init/1` if Shoehorn is loaded.

  See `Nerves.Release` for update information.
  """
  @spec init(Mix.Release.t()) :: Mix.Release.t()
  def init(%Mix.Release{} = release) do
    # Delegate to new implementation
    new_release = Nerves.init_release(release)

    if Code.ensure_loaded?(Shoehorn.Release) do
      # Apply the Shoehorn integration like Nerves 1.x did.
      new_release = apply(Shoehorn.Release, :init, [new_release])

      shoehorn_config =
        Application.get_all_env(:shoehorn) |> Keyword.take([:init, :last, :extra_dependencies])

      msg = """
      Calling `&Nerves.Release.init/1` from Mix releases is deprecated.

      TL;DR - most Nerves projects don't need this and you can skip to the
      numbered instructions below to remove this warning message.

      If you are using the Shoehorn library to automatically restart OTP
      applications, then you'll need to pay more care. Nerves 1.x had the side
      effect of calling `Shoehorn.Release.init/1` if it's available. That side
      effect is reproduced here for compatibility, but once you follow the
      instructions to remove this warning message, you'll need to explicitly
      call it. MOST users do not use this feature of Shoehorn!

      Here's how to update your code to remove this warning message:

      1. Edit your `mix.exs` update the `:include_erts` and `:steps` keys
         returned by the `release/0` function:

      ```
      def release do
        [
          ...
          include_erts: &Nerves.erts/0,
          steps: [&Nerves.init_release/1, :assemble],
          ...
        ]
      end
      ```

      2. Change the `:shoehorn` configuration in your app config (likely `config/target.exs`)

      ```
      # Before
      config :shoehorn, #{inspect(shoehorn_config) |> String.trim("[]")}

      # After
      config :nerves, application_sort: #{inspect(shoehorn_config)}
      ```

      3. Remove `{:shoehorn, "~> 0.9.0"}` from your Mix dependency list. Run `mix deps.unlock --unused`
         to remove it from your `mix.lock` file.

      See the `Nerves.Release` docs for details.
      """

      MixUtils.warning(msg)
      new_release
    else
      msg = """
      It looks like you've removed Shoehorn, but are still calling `&Nerves.Release.init/1`.

      Please replace with `&Nerves.Release.init/1` with `&Nerves.init_release/1` in your `mix.exs`.

      See the `Nerves.Release` docs for details.
      """

      MixUtils.warning(msg)
      new_release
    end
  end

  # Backwards compatibility
  @doc false
  @spec erts() :: Path.t() | boolean()
  def erts() do
    Nerves.erts()
  end
end
