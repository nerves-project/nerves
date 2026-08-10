# SPDX-FileCopyrightText: 2019 Justin Schneck
# SPDX-FileCopyrightText: 2023 Jon Carstens
# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Release do
  @moduledoc """
  Nerves 1.x mix release integration

  This modules provides the Nerves integration with Mix releases for
  projects using Nerves 1.x callbacks. If you have a new project, you
  probably won't need to read this.

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

  While this just looks like two functions moved to the top level `Nerves` module,
  making this change has the side effect of removing the Nerves 1.x Shoehorn
  hook insertion. Your firmware will likely still work without completing the
  Shoehorn migration, but please complete it to avoid future confusion.

  ## Migration from Shoehorn

  One of Shoehorn's features was to make release startup deterministic between
  firmware builds by sorting OTP application loads and starts alphabetically when
  no other dependency forced an ordering. Shoehorn also set OTP apps as `:temporary`
  so that application crashes wouldn't exit the Erlang VM and reboot. Both of these
  features are handled by Nerves now via the `Nerves.BuildAction.BootOrder` and
  `Nerves.BuildAction.AppModes` build actions.

  Most projects will only need to make the following update to their `config/target.exs`:

  ```
  # Before
  config :shoehorn, init: [:nerves_runtime, :nerves_pack]

  # After
  config :nerves, application_sort: [init: [:nerves_runtime, :nerves_pack]]
  ```

  See [Nerves.BuildAction.SortApps] for documentation on these config entries.

  If this is your only use of Shoehorn (likely), remove `:shoehorn` from your Mix dependency
  list.

  Internally, your OTP release start script will be `start.boot` now rather than `shoehorn.boot`.
  Erlinit is good about figuring this out as it will fall back to `start.boot` even
  when told to use `shoehorn.boot` if that file is missing. If you've created a custom
  Nerves system, you'll likely have at least one reference to `shoehorn.boot` that can be
  cleaned up.
  """

  alias Nerves.MixUtils

  @doc """
  Backwards compatible Nerves 1.x release

  This is the legacy entry point. It configures the release for embedded
  use and delegates to `Shoehorn.Release.init/1` if Shoehorn is loaded.

  See `Nerves.Release` for update information.
  """
  @spec init(Mix.Release.t()) :: Mix.Release.t()
  def init(%Mix.Release{} = release) do
    if Mix.target() == :host do
      release
    else
      msg = """
      Replace `&Nerves.Release.init/1` with `&Nerves.init_release/1`
      in your mix.exs's release config.

      Additionally, Nerves now handles OTP application ordering and mode
      assignment natively. This previously was handled by Shoehorn. If you are
      not using Shoehorn for anything else (most likely), you can safely delete
      the :shoehorn dependency with no loss of functionality. Once you delete
      Shoehorn, you will also need to move the `:shoehorn` configuration in your
      `config.exs` or `target.exs` to `:nerves`. It's probably something like:

      ```
      # Before
      config :shoehorn, init: [:nerves_runtime, :nerves_pack]

      # After
      config :nerves, application_sort: [init: [:nerves_runtime, :nerves_pack]]
      ```

      See `Nerves.Release` docs for details.
      """

      MixUtils.warning(msg)

      new_release = Nerves.init_release(release)

      if Code.ensure_loaded?(Shoehorn.Release) do
        apply(Shoehorn.Release, :init, [new_release])
      else
        new_release
      end
    end
  end

  # Backwards compatibility
  @doc false
  @spec erts() :: Path.t() | boolean()
  def erts() do
    Nerves.erts()
  end
end
