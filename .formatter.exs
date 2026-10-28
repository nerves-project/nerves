# SPDX-FileCopyrightText: None
#
# SPDX-License-Identifier: CC0-1.0
[
  inputs: ["mix.exs", ".credo.exs", ".formatter.exs", "{compat,config,lib,test}/**/*.{ex,exs}"],
  excludes: [
    "lib/nerves/treeshake/**/*.ex",
    "test/treeshake/**/*.exs",
    "test/fixtures/treeshake*/**/*"
  ]
]
