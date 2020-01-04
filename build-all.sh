#!/bin/bash
#
# For internal use only.
# Build everything on AWS EC2 ARM instance (a1.large works well).
#
# We take care to keep the total size of docker images small by pushing and
# pruning images often, since the default EC2 SSD size is only 8 GB and can't
# hold many images concurrently.

# Account name prefix for docker image tags.
readonly DOCKERHUB_USER='arturklauser'

source ./build-functions.sh

function main() {
  for debian_version in stretch buster bullseye; do
    # Throw out unreferenced junk from Docker.
    docker container prune --force
    docker image prune --force

    # Build our own bullseye starting image since there ain't any yet.
    if [[ "${debian_version}" == 'bullseye' ]]; then
      ./balenalib-bullseye-build.sh
    fi

    build 'build-env'
    (# handle docker in background
      push 'build-env'
      docker image prune --force
    ) &

    build 'desktop-deb'
    (# handle docker in background
      push 'desktop-deb'
      remove_image 'desktop-deb'
      docker image prune --force
    ) &

    build 'server-deb'
    (# handle docker in background
      push 'server-deb'
      remove_image 'build-env'
      docker image prune --force
    ) &

    build 'server'
    remove_image 'server-deb' &
    push 'server'
    remove_image 'server'
    wait # wait until all background processing has completed

    # Clean image repository thoroughly before going to next Debian version.
    docker image prune --all --force
  done
}

main "$@"
