# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
ExUnit.start()

# Exclude integration tests by default
# Run them with: mix test --include integration
ExUnit.configure(exclude: [integration: true])
