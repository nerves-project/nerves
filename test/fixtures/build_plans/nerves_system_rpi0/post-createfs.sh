#!/bin/sh

set -e

FWUP_CONFIG=$NERVES_DEFCONFIG_DIR/fwup.conf

if ! command -v mix > /dev/null 2>&1; then
    echo "ERROR: Elixir/Mix is required to generate fwup.conf but was not found on your PATH."
    echo "Please install Elixir: https://elixir-lang.org/install.html"
    exit 1
fi

(cd "$NERVES_DEFCONFIG_DIR" && ELIXIR_ERL_OPTIONS="+fnu" mix generate_fwup_conf)

# Run the common post-image processing for nerves
$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh $TARGET_DIR $FWUP_CONFIG
