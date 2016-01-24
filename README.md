# Nerves


## Installation

  1. Add nerves to your list of dependencies in `mix.exs`:

        def deps do
          [{:nerves, "~> 0.1"}]
        end

  2. Ensure nerves is started before your application:

        def application do
          [applications: [:nerves]]
        end
