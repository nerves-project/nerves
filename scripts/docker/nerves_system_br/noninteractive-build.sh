#!/usr/bin/env bash
# noninteractive-build.sh \
#  nerves_system_ev3-0.7.0.armv5tejl_unknown_linux_musleabi \
#  /nerves/env/platform \
#  /nerves/env/nerves_system_ev3/nerves_defconfig \
#  /nerves/o/nerves_system_ev3-0.7.0.armv5tejl_unknown_linux_musleabi
#  /nerves/host/artifacts

set -e

NERVES_ARTIFACT_NAME=$1
NERVES_PKG_PLATFORM=$2
NERVES_PKG_DEFCONFIG=$3
NERVES_PKG_OUTPUT=$4
NERVES_ARTIFACTS_DIR=$5

NERVES_PKG_OUTPUT=/nerves/o/package
echo "Artifacts Name"
echo $NERVES_ARTIFACT_NAME

echo "Pkg Platform"
echo $NERVES_PKG_PLATFORM

echo "Pkg Defconfig"
echo $NERVES_PKG_DEFCONFIG

echo "Artifacts Dir"
echo $NERVES_ARTIFACTS_DIR

rm -rf $NERVES_PKG_PLATFORM/buildroot*
$NERVES_PKG_PLATFORM/create-build.sh $NERVES_PKG_DEFCONFIG $NERVES_PKG_OUTPUT

cd $NERVES_PKG_OUTPUT
make source all

make system NERVES_ARTIFACT_NAME=$1
# Uncomment when switching to Artifact Type
# make artifact NERVES_ARTIFACT_NAME=$1

cp $NERVES_PKG_OUTPUT/$NERVES_ARTIFACT_NAME.tar.gz $NERVES_ARTIFACTS_DIR/$NERVES_ARTIFACT_NAME.tar.gz
