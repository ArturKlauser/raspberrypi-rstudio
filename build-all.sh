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

function docker_image_name() {
  local stage=$1
  echo "${DOCKERHUB_USER}/raspberrypi-rstudio-${stage}:${rstudio_version}-${debian_version}"
}

function build_message() {
  local stage=$1
  local message="========== building ${stage} ${rstudio_version}-${debian_version} =========="
  local line="${message//?/=}"
  echo "${line}"
  echo "${message}"
  echo "${line}"
}

function build() {
  local stage=$1
  build_message "${stage}"
  ./build.sh "${debian_version}" "${stage}"
}

function main() {
  for debian_version in stretch buster bullseye; do
    rstudio_version=$(./build.sh ${debian_version} 'rstudio-version')

    # Throw out unreferenced junk from Docker.
    docker container prune --force
    docker image prune --force

    # Build our own bullseye starting image since there ain't any yet.
    if [[ "${debian_version}" == 'bullseye' ]]; then
      ./balenalib-bullseye-build.sh
    fi

    build 'build-env'
    (# handle docker in background
      docker push "$(docker_image_name build-env)"
      docker image prune --force
    ) &

    build 'desktop-deb'
    (# handle docker in background
      docker push "$(docker_image_name desktop-deb)"
      docker rmi "$(docker_image_name desktop-deb)"
      docker image prune --force
    ) &

    build 'server-deb'
    (# handle docker in background
      docker push "$(docker_image_name server-deb)"
      docker rmi "$(docker_image_name build-env)"
      docker image prune --force
    ) &

    build 'server'
    docker rmi "$(docker_image_name server-deb)" &
    docker push "$(docker_image_name server)"
    docker rmi "$(docker_image_name server)"
    wait # wait until all background processing has completed

    # Clean image repository thoroughly before going to next Debian version.
    docker image prune --all --force
  done
}

main "$@"
