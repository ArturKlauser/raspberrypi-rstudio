#!/bin/bash
#
# Build an RStudio docker image.

# Account name prefix for docker image tags.
readonly DOCKERHUB_USER='arturklauser'

# Print usage message with error and exit.
function usage() {
  if [ "$#" != 0 ]; then
    (echo "$1"; echo) >&2
  fi
  cat - >&2 << END_USAGE
Usage: buildx.sh <debian-version> <build-stage>
         debian-version: stretch ... Debian version 9
                         buster .... Debian version 10
         build-stage: build-env ..... build environment
                      server-deb .... server Debian package
                      desktop-deb ... desktop Debian package
                      server ........ server runtime environment
END_USAGE
  exit 1
}

# Print standardized timestamp.
function timestamp() {
  date -u +'%Y-%m-%dT%H:%M:%SZ'
}

function main() {
  if [[ "$#" != 2 ]]; then
    usage "Invalid number ($#) of command line arguments."
  fi

  # Define build environment.
  readonly DEBIAN_VERSION="$1"
  readonly BUILD_STAGE="$2"

  echo "Start building at $(timestamp) ..."

  # Define RStudio source code version to use and the package release tag.
  case "${DEBIAN_VERSION}" in
   'stretch')
      # As of 2019-04-06 v1.1.463 is the latest version 1.1 tag.
      readonly VERSION_MAJOR=1
      readonly VERSION_MINOR=1
      readonly VERSION_PATCH=463
      readonly PACKAGE_RELEASE='2~r2r'
      ;;
    'buster')
      # As of 2019-10-26 v1.2.5019 is the latest version 1.2 tag.
      readonly VERSION_MAJOR=1
      readonly VERSION_MINOR=2
      readonly VERSION_PATCH=5019
      readonly PACKAGE_RELEASE='1~r2r'
      ;;
    *)
      usage "Unsupported Debian version '${DEBIAN_VERSION}'"
      ;;
  esac

  # Define image tag and dockerfile depending on requested build stage.
  case "${BUILD_STAGE}" in
   'build-env' | 'server-deb' | 'desktop-deb' | 'server')
     readonly IMAGE_NAME="${DOCKERHUB_USER}/raspberrypi-rstudio-${BUILD_STAGE}"
     readonly DOCKERFILE="docker/Dockerfile.${BUILD_STAGE}"
     ;;
    *)
      usage "Unsupported build stage '${BUILD_STAGE}'"
     ;;
  esac

  readonly VERSION_TAG=${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}
  readonly BUILD_PARALLELISM=2

  # We comment out the cross-build lines since buildx has cross-build
  # integrated already.
  #  if [[ $(uname -m) =~ 'arm' ]]; then
    readonly CROSS_BUILD_FIX='s/^(.*cross-build-.*)/# $1/'
  #  else
  #    readonly CROSS_BUILD_FIX=''
  #  fi

  # Build the docker image.
  #      --load \

  set -x
  time \
    perl -pe "${CROSS_BUILD_FIX}" "${DOCKERFILE}" \
    | perl -pe 's#^(FROM '"${DOCKERHUB_USER}"'/\S+)#$1-buildx#' \
    | docker buildx build \
      --platform linux/arm/v7 \
      --progress plain \
      --push \
      --build-arg DEBIAN_VERSION="${DEBIAN_VERSION}" \
      --build-arg VERSION_TAG="${VERSION_TAG}" \
      --build-arg VERSION_MAJOR="${VERSION_MAJOR}" \
      --build-arg VERSION_MINOR="${VERSION_MINOR}" \
      --build-arg VERSION_PATCH="${VERSION_PATCH}" \
      --build-arg PACKAGE_RELEASE="${PACKAGE_RELEASE}" \
      --build-arg BUILD_PARALLELISM="${BUILD_PARALLELISM}" \
      --build-arg VCS_REF=$(git log --pretty=format:'%H' HEAD~..HEAD) \
      --build-arg BUILD_DATE=$(timestamp) \
      -t "${IMAGE_NAME}:${VERSION_TAG}-${DEBIAN_VERSION}-buildx" \
      -
  set +x

  echo "Done building at $(timestamp)"
}

main "$@"
