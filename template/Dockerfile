############################################################
# Dockerfile build Nerves Systems
# Based on Ubuntu Image Xenial
############################################################
FROM ubuntu:xenial

MAINTAINER Justin Schneck

ENV NERVES_BR_DL_DIR=/nerves/cache/buildroot

# Set the locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN locale-gen en_US.UTF-8
RUN dpkg --add-architecture i386
RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  g++ \
  libssl-dev \
  libncurses5-dev \
  bc \
  m4 \
  make \
  unzip \
  cmake \
  bzip2 \
  wget \
  python \
  cpio \
  libc6:i386 \
  libncurses5:i386 \
  libstdc++6:i386 \
  xz-utils
