#!/bin/bash
#
# Balenalib doesn't currently distribute the built Debian SID (generic next
# release) or Bullseye (Debian 11) containers, so this tries to build a
# semblance of them based on their Dockerfile with some modifications.
# See: https://github.com/balena-io-library/base-images/blob/master/balena-base-images/device-base/raspberrypi3/debian/sid/run/Dockerfile

docker build \
  -f docker/Dockerfile.balenalib-raspberrypi3-debian-bullseye-run \
  -t balenalib-raspberrypi3-debian:bullseye-run \
  docker

docker build \
  -f docker/Dockerfile.balenalib-raspberrypi3-debian-bullseye-build \
  -t balenalib-raspberrypi3-debian:bullseye-build \
  docker
