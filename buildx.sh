#!/bin/bash
#
# Build an RStudio docker image.

readonly script_name=$(basename $0)

# Account name prefix for docker image tags.
readonly DOCKERHUB_USER='arturklauser'

# Print usage message with error and exit.
function usage() {
  if [ "$#" != 0 ]; then
    (echo "$1"; echo) >&2
  fi
  cat - >&2 << END_USAGE
Usage: $script_name <debian-version> <stage>
         debian-version: stretch ..... Debian version 9
                         buster ...... Debian version 10
                         bullseye .... Debian version 11 (experimental)
         stage: build-env ......... create build environment
                server-deb ........ build server Debian package
                desktop-deb ....... build desktop Debian package
                server ............ create server runtime environment
                rstudio-version ... print rstudio version
END_USAGE
  exit 1
}

# Print standardized timestamp.
function timestamp() {
  date -u +'%Y-%m-%dT%H:%M:%SZ'
}

# Return minimum of two numeric inputs.
function min() {
  if [[ "$1" -lt "$2" ]]; then
    echo $1
  else
    echo $2
  fi
}

function main() {
  cat <<EOF
==============================================================================
Note that this buildx.sh script depends on the experimental Docker support for
the _buildx_ plugin. Unless you know what you're doing, use build.sh instead.
==============================================================================

EOF

  if [[ "$#" != 2 ]]; then
    usage "Invalid number ($#) of command line arguments."
  fi

  # Define build environment.
  readonly DEBIAN_VERSION="$1"
  readonly BUILD_STAGE="$2"

  # Define RStudio source code version to use and the package release tag.
  case "${DEBIAN_VERSION}" in
   'stretch')
      # As of 2019-04-06 v1.1.463 is the latest version 1.1 tag.
      readonly VERSION_MAJOR=1
      readonly VERSION_MINOR=1
      readonly VERSION_PATCH=463
      readonly PACKAGE_RELEASE="2~r2r.${DEBIAN_VERSION}"
      ;;
    'buster')
      # As of 2019-10-26 v1.2.5019 is the latest version 1.2 tag.
      readonly VERSION_MAJOR=1
      readonly VERSION_MINOR=2
      readonly VERSION_PATCH=5019
      readonly PACKAGE_RELEASE="1~r2r.${DEBIAN_VERSION}"
      ;;
    'bullseye')
      # As of 2019-10-26 v1.2.5019 is the latest version 1.2 tag.
      readonly VERSION_MAJOR=1
      readonly VERSION_MINOR=2
      readonly VERSION_PATCH=5019
      readonly PACKAGE_RELEASE="1~r2r.${DEBIAN_VERSION}"
      ;;
    *)
      usage "Unsupported Debian version '${DEBIAN_VERSION}'"
      ;;
  esac

  readonly VERSION_TAG=${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}

  # Define image tag and dockerfile depending on requested build stage.
  case "${BUILD_STAGE}" in
   'build-env' | 'server-deb' | 'desktop-deb' | 'server')
     readonly IMAGE_NAME="${DOCKERHUB_USER}/raspberrypi-rstudio-${BUILD_STAGE}"
     readonly DOCKERFILE="docker/Dockerfile.${BUILD_STAGE}"
     ;;
   'rstudio-version')
     echo "${VERSION_TAG}"
     exit 0
     ;;
    *)
      usage "Unsupported build stage '${BUILD_STAGE}'"
     ;;
  esac

  echo "Start building at $(timestamp) ..."

  # Parallelism is no greater than number of available CPUs and max 2.
  readonly NPROC=$(nproc 2>/dev/null)
  readonly BUILD_PARALLELISM=$(min '2' "${NPROC}")

  # We comment out the cross-build lines since buildx has cross-build
  # integrated already.
  #  readonly ARCH=$(uname -m)
  #  if [[ ${ARCH} =~ 'arm' || ${ARCH} =~ 'aarch64' ]]; then
    readonly CROSS_BUILD_FIX='s/^(.*cross-build-.*)/# $1/'
  #  else
  #    readonly CROSS_BUILD_FIX=''
  #  fi
  if [[ "${DEBIAN_VERSION}" == 'bullseye' ]]; then
    readonly BULLSEYE_FIX='s#(balenalib)/(raspberrypi3)#$1-$2#'
  else
    readonly BULLSEYE_FIX=''
  fi

  # Build the docker image.
  #      --load \

  set -x
  time \
    perl -pe "${CROSS_BUILD_FIX}" "${DOCKERFILE}" \
    | perl -pe "${BULLSEYE_FIX}" \
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
