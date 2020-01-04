#!/bin/bash
#
# For internal use only.

function docker_image_name() {
  local stage=$1
  # shellcheck disable=SC2154
  local -r rstudio_version=$(./build.sh "${debian_version}" 'rstudio-version')
  echo "${DOCKERHUB_USER}/raspberrypi-rstudio-${stage}:${rstudio_version}-${debian_version}"
}

function build_message() {
  local stage=$1
  local -r rstudio_version=$(./build.sh "${debian_version}" 'rstudio-version')
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

function push() {
  local stage=$1
  docker push "$(docker_image_name "${stage}")"
}

function remove_image() {
  local stage=$1
  docker rmi "$(docker_image_name "${stage}")"
}
