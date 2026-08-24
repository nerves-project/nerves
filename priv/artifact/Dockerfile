# SPDX-FileCopyrightText: None
#
# SPDX-License-Identifier: CC0-1.0
#
# Artifact containers receive a mounted /workspace directory containing:
#   /workspace/<package>  package source and Nerves-aware dependencies
#   /workspace/build      persistent build output
#   /workspace/dl         shared download cache and NERVES_ARTIFACT_DIR output
#
# The build command must copy every generated artifact archive to
# NERVES_ARTIFACT_DIR.
#
# Nerves supplies these environment variables:
#   NERVES_ARTIFACT_APP                 package name
#   NERVES_ARTIFACT_VERSION             package version
#   NERVES_ARTIFACT_SOURCE_FINGERPRINT  package source fingerprint
#   NERVES_ARTIFACT_DIR                 output directory for artifact archives
#   NERVES_BR_DL_DIR                    shared download cache (namespace downloads by package name)
#   NERVES_HOST_TUPLE                   host tuple of the computer running Nerves
#   TERM                                terminal type
#
# Nerves supplies the calling task's ELIXIR_VERSION and OTP_RELEASE as Docker
# build arguments. There's no Nerves requirement to match them or even install
# Elixir or Erlang.
#
# The image must provide /usr/local/bin/nerves-artifact as its ENTRYPOINT. It
# receives `build` for artifact builds and `shell` for interactive shells.
FROM ghcr.io/nerves-project/nerves_system_br:latest

USER root

ARG ELIXIR_VERSION
ARG OTP_RELEASE

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates git make \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/elixir-otp-${OTP_RELEASE}.zip -o /tmp/elixir.zip \
 && unzip -q /tmp/elixir.zip -d /usr/local \
 && rm -f /tmp/elixir.zip

COPY nerves-artifact /usr/local/bin/nerves-artifact
RUN chmod +x /usr/local/bin/nerves-artifact

USER nerves
WORKDIR /workspace/build
ENTRYPOINT ["/usr/local/bin/nerves-artifact"]
CMD ["build"]
