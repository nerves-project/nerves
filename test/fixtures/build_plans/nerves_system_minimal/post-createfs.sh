#!/bin/sh

set -ex

# Run the common post-image processing for nerves
$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh \
  $TARGET_DIR \
  $NERVES_DEFCONFIG_DIR/fwup.conf
