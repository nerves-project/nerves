import Config

Application.start(:nerves_bootstrap)

if Mix.target() == :host do
  import_config "host.exs"
end
