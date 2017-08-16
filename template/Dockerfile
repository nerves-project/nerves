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

RUN DEBIAN_FRONTEND=noninteractive \
  dpkg --add-architecture i386 && \
  apt-get update -y && \
  apt-get install -y \
  locales \
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
  xz-utils && \
  rm -rf /var/lib/apt/lists/* && \
  localedef -i en_US -f UTF-8 en_US.UTF-8
