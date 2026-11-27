# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#

# A stand-in for a companion package that has an installer. The real toolshed
# installer adds this line to the device's IEx startup file too. The other
# companions don't have installers in this project, so both paths are tested.
defmodule Mix.Tasks.Toolshed.Install do
  @moduledoc false
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    path = "rootfs_overlay/etc/iex.exs"

    if Igniter.exists?(igniter, path) do
      Igniter.update_file(igniter, path, fn source ->
        content = Rewrite.Source.get(source, :content)

        if content =~ "use Toolshed",
          do: source,
          else: Rewrite.Source.update(source, :content, content <> "\nuse Toolshed\n")
      end)
    else
      Igniter.add_issue(igniter, "toolshed.install ran before #{path} was created")
    end
  end
end

defmodule Mix.Tasks.Nerves.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  # Igniter evaluates config/config.exs. That file starts nerves_bootstrap,
  # which logs since the archive isn't loaded.
  @moduletag capture_log: true

  # test_helper.exs clears the Mix project stack, so ask the application
  @nerves_requirement (case Version.parse!("#{Application.spec(:nerves, :vsn)}") do
                         %Version{pre: []} = v -> "~> #{v.major}.#{v.minor}"
                         v -> "~> #{v}"
                       end)

  @sup_mix_exs """
  defmodule Test.MixProject do
    use Mix.Project

    def project do
      [
        app: :test,
        version: "0.1.0",
        elixir: "~> 1.17",
        start_permanent: Mix.env() == :prod,
        deps: deps()
      ]
    end

    def application do
      [
        extra_applications: [:logger],
        mod: {Test.Application, []}
      ]
    end

    defp deps do
      []
    end
  end
  """

  @sup_application """
  defmodule Test.Application do
    # See https://hexdocs.pm/elixir/Application.html
    # for more information on OTP Applications
    @moduledoc false

    use Application

    @impl true
    def start(_type, _args) do
      children = [
        # Starts a worker by calling: Test.Worker.start_link(arg)
        # {Test.Worker, arg}
      ]

      # See https://hexdocs.pm/elixir/Supervisor.html
      # for other strategies and supported options
      opts = [strategy: :one_for_one, name: Test.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  """

  @mix_new_readme """
  # Test

  **TODO: Add description**

  ## Installation

  If [available in Hex](https://hex.pm/docs/publish), the package can be installed
  by adding `test` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:test, "~> 0.1.0"}
    ]
  end
  ```

  Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
  and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
  be found at <https://hexdocs.pm/test>.
  """

  @nerves_1_mix_exs """
  defmodule Test.MixProject do
    use Mix.Project

    @app :test
    @version "0.1.0"
    @all_targets [:rpi0, :rpi4]

    def project do
      [
        app: @app,
        version: @version,
        elixir: "~> 1.17",
        archives: [nerves_bootstrap: "~> 1.13"],
        start_permanent: Mix.env() == :prod,
        deps: deps(),
        releases: [{@app, release()}]
      ]
    end

    def application do
      [extra_applications: [:logger, :runtime_tools]]
    end

    def cli do
      [preferred_targets: [run: :host, test: :host]]
    end

    defp deps do
      [
        {:nerves, "~> 1.10", runtime: false},
        {:shoehorn, "~> 0.9.1"},
        {:ring_logger, "~> 0.11.0"},
        {:toolshed, "~> 0.4.0"},
        {:nerves_runtime, "~> 0.13.0"},
        {:nerves_pack, "~> 0.7.1", targets: @all_targets},
        {:nerves_system_rpi0, "~> 1.24", runtime: false, targets: :rpi0},
        {:nerves_system_rpi4, "~> 1.24", runtime: false, targets: :rpi4}
      ]
    end

    def release do
      [
        overwrite: true,
        cookie: "\#{@app}_cookie",
        include_erts: &Nerves.Release.erts/0,
        steps: [&Nerves.Release.init/1, :assemble],
        strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
      ]
    end
  end
  """

  @nerves_1_files %{
    "mix.exs" => @nerves_1_mix_exs,
    ".gitignore" => "/_build/\n",
    "config/config.exs" => """
    import Config

    # Enable the Nerves integration with Mix
    Application.start(:nerves_bootstrap)

    config :test, target: Mix.target()

    config :nerves, :firmware, rootfs_overlay: "overlay"
    config :nerves, source_date_epoch: "1700000000"

    if Mix.target() == :host do
      import_config "host.exs"
    else
      import_config "target.exs"
    end
    """,
    "config/host.exs" => "import Config\n\nconfig :test, host: true\n",
    "config/target.exs" => """
    import Config

    config :shoehorn, init: [:nerves_runtime, :nerves_pack]

    config :logger, backends: [RingLogger]
    """,
    "rel/vm.args.eex" => "## My flags\n-heart\n",
    "rootfs_overlay/etc/iex.exs" => "use Toolshed\n"
  }

  defp install(igniter, argv \\ []) do
    Igniter.compose_task(igniter, "nerves.install", argv)
  end

  defp content(igniter, path) do
    igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
  end

  defp systems(igniter) do
    Regex.scan(~r/\{:(nerves_system_\w+),/, content(igniter, "mix.exs"), capture: :all_but_first)
    |> List.flatten()
  end

  describe "info/2" do
    test "adds the companion packages without using their installers as prerequisites" do
      info = Mix.Tasks.Nerves.Install.info([], nil)

      assert info.schema == [target: :keep]
      assert info.installs == []

      assert info.adds_deps == [
               {:shoehorn, "~> 0.9.1"},
               {:nerves_runtime, "~> 0.13.12"},
               {:ring_logger, "~> 0.11.0"},
               {:toolshed, "~> 0.5.0"}
             ]

      assert info.composes == [
               "shoehorn.install",
               "nerves_runtime.install",
               "ring_logger.install",
               "toolshed.install"
             ]
    end
  end

  describe "in a new project" do
    test "updates the mix.exs" do
      igniter = install(test_project(), ["--target", "rpi4"])

      assert content(igniter, "mix.exs") == """
             defmodule Elixir.Test.MixProject do
               use Mix.Project

               @all_targets [:rpi4]

               def project do
                 [
                   app: :test,
                   version: "0.1.0",
                   elixir: "~> 1.17",
                   start_permanent: Mix.env() == :prod,
                   deps: deps(),
                   archives: [nerves_bootstrap: "~> 1.17"],
                   releases: [{:test, release()}],
                   nerves_targets: @all_targets
                 ]
               end

               # Run "mix help compile.app" to learn about applications.
               def application do
                 [
                   extra_applications: [:logger, :runtime_tools],
                   mod: {Test.Application, []}
                 ]
               end

               def release do
                 [
                   overwrite: true,
                   cookie: "test_cookie",
                   include_erts: &Nerves.Release.erts/0,
                   steps: [&Nerves.Release.init/1, :assemble],
                   strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
                 ]
               end

               def cli do
                 [
                   preferred_targets: [run: :host, test: :host]
                 ]
               end

               # Run "mix help deps" to learn about dependencies.
               defp deps do
                 [
                   {:nerves, "#{@nerves_requirement}", runtime: false},
                   {:shoehorn, "~> 0.9.1"},
                   {:nerves_runtime, "~> 0.13.12"},
                   {:ring_logger, "~> 0.11.0"},
                   {:toolshed, "~> 0.5.0"},
                   {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}
                   # {:dep_from_hexpm, "~> 0.3.0"},
                   # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
                 ]
               end
             end
             """
    end

    test "creates the config files" do
      igniter = install(test_project())

      config_exs = content(igniter, "config/config.exs")
      assert [_, epoch] = Regex.run(~r/config :nerves, source_date_epoch: "(\d+)"/, config_exs)
      assert_in_delta String.to_integer(epoch), System.os_time(:second), 60

      assert String.replace(config_exs, epoch, "EPOCH") == """
             # This file is responsible for configuring your application and its
             # dependencies.
             #
             # This configuration file is loaded before any dependency and is restricted to
             # this project.
             import Config

             # Enable the Nerves integration with Mix
             Application.start(:nerves_bootstrap)

             # Customize non-Elixir parts of the firmware. See
             # https://nerves.hexdocs.pm/advanced-configuration.html for details.

             config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

             # Set the SOURCE_DATE_EPOCH date for reproducible builds.
             # See https://reproducible-builds.org/docs/source-date-epoch/ for more information

             config :nerves, source_date_epoch: "EPOCH"

             if Mix.target() == :host do
               import_config "host.exs"
             else
               import_config "target.exs"
             end
             """

      assert_creates(igniter, "config/host.exs", """
      import Config

      # Add configuration that is only needed when running on the host here.
      """)

      assert_creates(igniter, "config/target.exs", """
      import Config

      # Use shoehorn to start the main application. See the shoehorn
      # library documentation for more control in ordering how OTP
      # applications are started and handling failures.

      config :shoehorn, init: [:nerves_runtime]

      # Erlinit can be configured without a rootfs_overlay. See
      # https://github.com/nerves-project/erlinit/ for more information on
      # configuring erlinit.

      # Advance the system clock on devices without a real-time clock.
      config :nerves, :erlinit, update_clock: true

      # Import target specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      # Uncomment to use target specific configurations

      # import_config "\#{Mix.target()}.exs"
      """)
    end

    test "creates the vm.args with the flags that other installers look for" do
      igniter = install(test_project())
      vm_args = content(igniter, "rel/vm.args.eex")

      assert vm_args =~ "\n-env HEART_INIT_TIMEOUT 600\n"
      assert vm_args =~ "\n+C multi_time_warp\n"
      assert vm_args =~ "\n-heart -env HEART_BEAT_TIMEOUT 30\n"
      assert vm_args =~ "\n-code_path_choice strict\n"
      assert vm_args =~ "\n-user elixir\n-run elixir start_cli\n"
      assert String.ends_with?(vm_args, "-extra --no-halt\n--\n--dot-iex /etc/iex.exs\n")

      # The vm.args is an EEx template. Nothing should be left to evaluate.
      assert EEx.eval_string(vm_args) == vm_args
    end

    test "creates the IEx startup file before running companion installers" do
      igniter = install(test_project())

      assert igniter.issues == []

      assert content(igniter, "rootfs_overlay/etc/iex.exs") =~
               ~r/\A# This file is run.*\n\nuse Toolshed\n\z/s
    end

    test "formats the IEx startup file and ignores firmware images" do
      igniter = install(test_project())

      assert_has_patch(igniter, ".formatter.exs", """
      - |  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
      + |  inputs: [
      + |    "{mix,.formatter}.exs",
      + |    "{config,lib,test}/**/*.{ex,exs}",
      + |    "rootfs_overlay/etc/iex.exs"
      + |  ]
      """)

      assert content(igniter, ".gitignore") =~
               ~s|\n\n# Firmware images created by "mix firmware.image"\n/*.img\n|
    end

    test "tells the user what to do next and which installers didn't run" do
      igniter = install(test_project())

      assert_has_notice(igniter, &(&1 =~ "mix archive.install hex nerves_bootstrap"))

      assert_has_notice(
        igniter,
        &(&1 =~ "the installers for shoehorn, nerves_runtime, ring_logger weren't available" and
            &1 =~ "mix igniter.install shoehorn nerves_runtime ring_logger\n")
      )

      assert length(igniter.notices) == 2
      assert igniter.warnings == []
      assert igniter.issues == []
    end

    test "is idempotent" do
      test_project()
      |> install(["--target", "rpi4"])
      |> apply_igniter!()
      |> install(["--target", "rpi4"])
      |> assert_unchanged()
    end

    test "creates the application module with children for the host and for devices" do
      igniter = install(test_project())

      assert_creates(igniter, "lib/test/application.ex")
      application = content(igniter, "lib/test/application.ex")

      assert application =~ "defmodule Test.Application do"
      assert application =~ "] ++ target_children()"
      assert application =~ "if Mix.target() == :host do"
      assert application =~ "opts = [strategy: :one_for_one, name: Test.Supervisor]"
      assert application =~ "# {Test.Worker, arg},"
      assert {:ok, _} = Code.string_to_quoted(application)
    end

    test "replaces the application module from `mix new --sup` when it's unmodified" do
      igniter =
        test_project(
          files: %{"mix.exs" => @sup_mix_exs, "lib/test/application.ex" => @sup_application}
        )
        |> install()

      assert content(igniter, "lib/test/application.ex") =~ "] ++ target_children()"
      assert content(igniter, "mix.exs") =~ "mod: {Test.Application, []}"
    end

    test "keeps an application module that was modified" do
      modified = String.replace(@sup_application, ":one_for_one", ":rest_for_one")

      test_project(files: %{"mix.exs" => @sup_mix_exs, "lib/test/application.ex" => modified})
      |> install()
      |> assert_unchanged("lib/test/application.ex")
    end

    test "keeps an application module that has another name" do
      mix_exs = String.replace(@sup_mix_exs, "Test.Application", "Test.App")

      igniter =
        test_project(
          files: %{
            "mix.exs" => mix_exs,
            "lib/test/app.ex" => String.replace(@sup_application, "Test.Application", "Test.App")
          }
        )
        |> install()

      assert_unchanged(igniter, "lib/test/app.ex")
      refute Igniter.exists?(igniter, "lib/test/application.ex")
      assert content(igniter, "mix.exs") =~ "mod: {Test.App, []}"
    end

    test "adds :runtime_tools without touching other extra applications" do
      mix_exs = String.replace(@sup_mix_exs, "[:logger]", "[:logger, :crypto]")
      igniter = install(test_project(files: %{"mix.exs" => mix_exs}))

      assert content(igniter, "mix.exs") =~
               "extra_applications: [:logger, :crypto, :runtime_tools]"
    end

    test "replaces the README from `mix new`" do
      igniter = install(test_project(files: %{"README.md" => @mix_new_readme}))
      readme = content(igniter, "README.md")

      assert readme =~ ~r/\A# Test\n\n\*\*TODO: Add description\*\*\n\n## Targets\n/
      assert readme =~ "Create firmware with `mix firmware`"
      refute readme =~ "available in Hex"
    end

    test "keeps a README that was modified" do
      readme = String.replace(@mix_new_readme, "**TODO: Add description**", "My project")

      test_project(files: %{"README.md" => readme})
      |> install()
      |> assert_unchanged("README.md")
    end

    test "doesn't repeat the next steps when run again" do
      igniter = test_project() |> install() |> apply_igniter!() |> install()

      assert [notice] = igniter.notices
      assert notice =~ "the installers for"
    end
  end

  describe "--target" do
    test "defaults to the same targets as mix nerves.new" do
      igniter = install(test_project())

      assert systems(igniter) ==
               Enum.map(Nerves.Igniter.default_targets(), &"nerves_system_#{&1}")

      assert Nerves.Igniter.project_targets(igniter) == Nerves.Igniter.default_targets()
    end

    test "can be repeated" do
      igniter = install(test_project(), ["--target", "rpi4", "--target", "rpi0"])

      assert Nerves.Igniter.project_targets(igniter) == [:rpi4, :rpi0]
    end

    test "can be comma separated" do
      igniter = install(test_project(), ["--target", "rpi4,rpi0", "--target", "bbb, rpi4"])

      assert Nerves.Igniter.project_targets(igniter) == [:rpi4, :rpi0, :bbb]
    end

    test "supports official targets that aren't defaults" do
      igniter = install(test_project(), ["--target", "grisp2"])

      assert content(igniter, "mix.exs") =~
               ~s|{:nerves_system_grisp2, "~> 0.8", runtime: false, targets: :grisp2}|
    end

    test "adds to the targets of an existing project" do
      igniter =
        test_project()
        |> install(["--target", "rpi4"])
        |> apply_igniter!()
        |> install(["--target", "rpi5"])

      assert Nerves.Igniter.project_targets(igniter) == [:rpi4, :rpi5]
    end

    test "doesn't add the defaults to a project that has a system" do
      test_project()
      |> install(["--target", "rpi4"])
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end

    test "doesn't add the defaults to a project that has a custom system" do
      mix_exs =
        String.replace(
          content(test_project(), "mix.exs"),
          "# {:dep_from_hexpm, \"~> 0.3.0\"},",
          ~s|{:nerves_system_custom, path: "../custom", runtime: false, targets: @targets}|
        )

      igniter = install(test_project(files: %{"mix.exs" => mix_exs}))

      assert systems(igniter) == ["nerves_system_custom"]
    end

    test "fails on unknown targets without changing anything" do
      igniter = install(test_project(), ["--target", "rpi4,my_board"])

      assert_has_issue(igniter, &(&1 =~ "Unknown Nerves target :my_board"))
      assert_unchanged(igniter)
    end
  end

  describe "in a project with existing files" do
    test "marks the nerves dependency that `mix igniter.install` added" do
      mix_exs =
        String.replace(
          content(test_project(), "mix.exs"),
          "# {:dep_from_hexpm, \"~> 0.3.0\"},",
          ~s|{:nerves, "~> 1.15"}|
        )

      igniter = install(test_project(files: %{"mix.exs" => mix_exs}))

      assert content(igniter, "mix.exs") =~ ~s|{:nerves, "~> 1.15", runtime: false}|
      assert_has_notice(igniter, &(&1 =~ "your project is now a Nerves project"))
    end

    test "keeps Igniter out of the firmware" do
      mix_exs = fn igniter_dep ->
        String.replace(@sup_mix_exs, "    []\n", "    [\n      #{igniter_dep}\n    ]\n")
      end

      # What `mix igniter.new` adds
      igniter =
        test_project(
          files: %{"mix.exs" => mix_exs.(~s|{:igniter, "~> 0.6", only: [:dev, :test]}|)}
        )
        |> install()

      assert content(igniter, "mix.exs") =~
               ~s|{:igniter, "~> 0.6", only: [:dev, :test], runtime: false}|

      igniter =
        test_project(files: %{"mix.exs" => mix_exs.(~s|{:igniter, "~> 0.6"}|)}) |> install()

      assert content(igniter, "mix.exs") =~ ~s|{:igniter, "~> 0.6", runtime: false}|

      # An explicit choice is kept
      igniter =
        test_project(files: %{"mix.exs" => mix_exs.(~s|{:igniter, "~> 0.6", runtime: true}|)})
        |> install()

      assert content(igniter, "mix.exs") =~ ~s|{:igniter, "~> 0.6", runtime: true}|
    end

    test "updates an existing config.exs without touching what's there" do
      config_exs = """
      import Config

      config :test, key: :value

      config :nerves, source_date_epoch: "1700000000"

      import_config "\#{config_env()}.exs"
      """

      igniter = install(test_project(files: %{"config/config.exs" => config_exs}))

      assert content(igniter, "config/config.exs") == """
             import Config

             # Enable the Nerves integration with Mix
             Application.start(:nerves_bootstrap)
             config :test, key: :value

             config :nerves, source_date_epoch: "1700000000", firmware: [rootfs_overlay: "rootfs_overlay"]

             import_config "\#{config_env()}.exs"

             if Mix.target() == :host do
               import_config "host.exs"
             else
               import_config "target.exs"
             end
             """

      igniter |> apply_igniter!() |> install() |> assert_unchanged()
    end

    test "keeps existing files" do
      files = %{
        "config/host.exs" => "import Config\n\nconfig :test, host: true\n",
        "rel/vm.args.eex" => "## My flags\n-heart\n",
        "rootfs_overlay/etc/iex.exs" => "IO.puts(\"Hello\")\nuse Toolshed\n",
        ".gitignore" => "/_build/\n*.img\n"
      }

      igniter = install(test_project(files: files))

      assert_unchanged(igniter, Map.keys(files))
    end

    test "adds the shoehorn init list to an existing target.exs" do
      files = %{"config/target.exs" => "import Config\n\nconfig :test, target: true\n"}

      igniter = install(test_project(files: files))

      assert content(igniter, "config/target.exs") == """
             import Config

             config :shoehorn, init: [:nerves_runtime]
             config :test, target: true

             # Erlinit can be configured without a rootfs_overlay. See
             # https://github.com/nerves-project/erlinit/ for more information on
             # configuring erlinit.

             # Advance the system clock on devices without a real-time clock.
             config :nerves, :erlinit, update_clock: true
             """
    end

    test "advances the clock at boot above a trailing import_config" do
      files = %{
        "config/target.exs" => """
        import Config

        config :shoehorn, init: [:my_app]

        # Import target specific config.

        import_config "\#{Mix.target()}.exs"
        """
      }

      igniter = install(test_project(files: files))

      assert content(igniter, "config/target.exs") == """
             import Config

             config :shoehorn, init: [:my_app]

             # Erlinit can be configured without a rootfs_overlay. See
             # https://github.com/nerves-project/erlinit/ for more information on
             # configuring erlinit.

             # Advance the system clock on devices without a real-time clock.
             config :nerves, :erlinit, update_clock: true

             # Import target specific config.

             import_config "\#{Mix.target()}.exs"
             """

      igniter |> apply_igniter!() |> install() |> assert_unchanged()
    end

    test "keeps an existing erlinit configuration" do
      for erlinit <- [
            "config :nerves, :erlinit, update_clock: false",
            "config :nerves, :erlinit, hostname_pattern: \"my-%s\"",
            "config :nerves, erlinit: [ctty: \"ttyAMA0\"]"
          ] do
        files = %{
          "config/target.exs" => """
          import Config

          config :shoehorn, init: [:my_app]

          #{erlinit}
          """
        }

        test_project(files: files) |> install() |> assert_unchanged("config/target.exs")
      end
    end

    test "keeps an erlinit configuration that's in config.exs" do
      files = %{
        "config/config.exs" => """
        import Config

        config :nerves, :erlinit, ctty: "ttyAMA0"
        """
      }

      igniter = install(test_project(files: files))

      refute content(igniter, "config/target.exs") =~ "erlinit"
    end

    test "keeps an existing shoehorn init list" do
      files = %{
        "config/target.exs" => """
        import Config

        config :shoehorn, init: [:my_app], last: [:iex]
        """
      }

      igniter = install(test_project(files: files))

      assert content(igniter, "config/target.exs") =~
               "config :shoehorn, init: [:my_app], last: [:iex]\n"
    end

    test "leaves an existing releases configuration alone" do
      mix_exs =
        String.replace(
          content(test_project(), "mix.exs"),
          "deps: deps()",
          "deps: deps(),\n      releases: [test: [include_erts: false]]"
        )

      igniter = install(test_project(files: %{"mix.exs" => mix_exs}))

      assert content(igniter, "mix.exs") =~ "releases: [test: [include_erts: false]]"
      refute content(igniter, "mix.exs") =~ "def release do"
      assert_has_notice(igniter, &(&1 =~ "steps: [&Nerves.Release.init/1, :assemble]"))
    end
  end

  describe "in a Nerves 1.x project" do
    test "doesn't touch the mix.exs" do
      igniter = install(test_project(files: @nerves_1_files))

      assert content(igniter, "mix.exs") == @nerves_1_mix_exs
    end

    test "doesn't touch any other file" do
      igniter = install(test_project(files: @nerves_1_files))

      assert_unchanged(igniter, [
        "config/config.exs",
        "config/host.exs",
        "rel/vm.args.eex",
        "rootfs_overlay/etc/iex.exs",
        "README.md"
      ])

      refute Igniter.exists?(igniter, "lib/test/application.ex")
    end

    test "only adds the clock configuration to the target.exs" do
      igniter = install(test_project(files: @nerves_1_files))

      assert content(igniter, "config/target.exs") == """
             import Config

             config :shoehorn, init: [:nerves_runtime, :nerves_pack]

             config :logger, backends: [RingLogger]

             # Erlinit can be configured without a rootfs_overlay. See
             # https://github.com/nerves-project/erlinit/ for more information on
             # configuring erlinit.

             # Advance the system clock on devices without a real-time clock.
             config :nerves, :erlinit, update_clock: true
             """

      igniter |> apply_igniter!() |> install() |> assert_unchanged()
    end

    test "doesn't tell the user that it's a new Nerves project" do
      igniter = install(test_project(files: @nerves_1_files))

      refute Enum.any?(igniter.notices, &(&1 =~ "your project is now a Nerves project"))
    end

    test "adds new targets to @all_targets" do
      igniter = install(test_project(files: @nerves_1_files), ["--target", "rpi5,rpi4"])
      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~ "@all_targets [:rpi0, :rpi4, :rpi5]\n"
      assert mix_exs =~ ~s|{:nerves_system_rpi4, "~> 1.24", runtime: false, targets: :rpi4},\n|
      assert mix_exs =~ ~s|{:nerves_system_rpi5, "~> 2.0", runtime: false, targets: :rpi5}\n|
    end
  end

  describe "@all_targets" do
    test "is created from the targets in the order that they were passed" do
      igniter = install(test_project(), ["--target", "rpi4", "--target", "rpi0,bbb"])
      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~
               "  use Mix.Project\n\n  @all_targets [:rpi4, :rpi0, :bbb]\n\n  def project do\n"

      assert mix_exs =~ "      nerves_targets: @all_targets\n"
    end

    test "is created with the default targets" do
      igniter = install(test_project())

      # The formatter breaks the list up since it's too long for one line
      assert [_, list] =
               Regex.run(~r/^  @all_targets (\[[^\]]*\])$/m, content(igniter, "mix.exs"))

      assert Code.eval_string(list) == {Nerves.Igniter.default_targets(), []}
    end

    test "is extended when a target is added later" do
      igniter =
        test_project()
        |> install(["--target", "rpi4"])
        |> apply_igniter!()
        |> install(["--target", "rpi0"])

      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~ "  @all_targets [:rpi4, :rpi0]\n"
      assert length(String.split(mix_exs, "@all_targets")) == 3

      igniter |> apply_igniter!() |> install(["--target", "rpi0,rpi4"]) |> assert_unchanged()
    end

    test "is created for the systems of a Nerves project that doesn't have it" do
      mix_exs =
        @nerves_1_mix_exs
        |> String.replace("  @all_targets [:rpi0, :rpi4]\n", "")
        |> String.replace(~s|      {:nerves_pack, "~> 0.7.1", targets: @all_targets},\n|, "")

      igniter = install(test_project(files: %{@nerves_1_files | "mix.exs" => mix_exs}))
      mix_exs = content(igniter, "mix.exs")

      # Next to the other module attributes like in the `mix nerves.new` template
      assert mix_exs =~
               "  @version \"0.1.0\"\n  @all_targets [:rpi0, :rpi4]\n\n  def project do\n"

      assert mix_exs =~ "      nerves_targets: @all_targets\n"

      igniter |> apply_igniter!() |> install() |> assert_unchanged()
    end

    test "is left alone when it exists" do
      # Neither the user's list nor how it's used is changed. :rpi4 has a
      # system, but was left out of the list.
      mix_exs =
        String.replace(@nerves_1_mix_exs, "@all_targets [:rpi0, :rpi4]", "@all_targets [:rpi0]")

      igniter = install(test_project(files: %{@nerves_1_files | "mix.exs" => mix_exs}))
      mix_exs = content(igniter, "mix.exs")

      assert mix_exs =~ "  @all_targets [:rpi0]\n"
      assert mix_exs =~ ~s|{:nerves_pack, "~> 0.7.1", targets: @all_targets},\n|
      refute mix_exs =~ "nerves_targets"
    end

    test "isn't referenced from project/0 when the reference was removed" do
      igniter = test_project() |> install(["--target", "rpi4"]) |> apply_igniter!()

      mix_exs =
        igniter
        |> content("mix.exs")
        |> String.replace(",\n      nerves_targets: @all_targets", "")
        |> String.replace(
          ~s|{:toolshed, "~> 0.5.0"},|,
          ~s|{:toolshed, "~> 0.5.0", targets: @all_targets},|
        )

      refute mix_exs =~ "nerves_targets"

      test_project(files: Map.put(igniter.assigns[:test_files], "mix.exs", mix_exs))
      |> install(["--target", "rpi0"])
      |> then(fn igniter ->
        mix_exs = content(igniter, "mix.exs")
        assert mix_exs =~ "@all_targets [:rpi4, :rpi0]\n"
        refute mix_exs =~ "nerves_targets"
      end)
    end

    test "isn't created when the project's targets are unknown" do
      mix_exs =
        @nerves_1_mix_exs
        |> String.replace("  @all_targets [:rpi0, :rpi4]\n", "  @boards [:rpi0, :rpi4]\n")
        |> String.replace(~s|      {:nerves_pack, "~> 0.7.1", targets: @all_targets},\n|, "")
        |> String.replace(
          ~s|      {:nerves_system_rpi0, "~> 1.24", runtime: false, targets: :rpi0},\n|,
          ""
        )
        |> String.replace("targets: :rpi4}", "targets: @boards}")

      igniter = install(test_project(files: %{@nerves_1_files | "mix.exs" => mix_exs}))

      refute content(igniter, "mix.exs") =~ "@all_targets"
    end
  end

  describe "in a project that it set up" do
    test "changes nothing" do
      test_project()
      |> install(["--target", "rpi4"])
      |> apply_igniter!()
      |> install()
      |> assert_unchanged()
    end
  end
end
