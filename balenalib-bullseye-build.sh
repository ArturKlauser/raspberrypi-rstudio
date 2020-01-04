#!/bin/bash
#
# Balenalib doesn't currently distribute the built Debian SID (generic next
# release) or Bullseye (Debian 11) containers, so this tries to build a
# semblance of them based on their Dockerfile with some modifications.
# See: https://github.com/balena-io-library/base-images/blob/master/balena-base-images/device-base/raspberrypi3/debian/sid/run/Dockerfile
#
# You need to build these containers before you try to build 'bullseye' versions
# or RStudio with build.sh bullseye <build-stage>

function build_balenalib() {
  local -r variant=$1
  docker build \
    -f "docker/Dockerfile.balenalib-raspberrypi3-debian-bullseye-${variant}" \
    -t "balenalib-raspberrypi3-debian:bullseye-${variant}" \
    docker
}

function main() {
  local -r default=('run' 'build')
  for variant in "${@:-${default[@]}}"; do
    build_balenalib "${variant}"
  done
}

main "$@"
