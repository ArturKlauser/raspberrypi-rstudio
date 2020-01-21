#!/bin/bash
#
# For internal use only.

function docker_image_name() {
  local stage=$1
  # shellcheck disable=SC2154
  local -r rstudio_version=$(./build.sh "${debian_version}" 'rstudio-version')
  echo "${DOCKERHUB_USER}/${GITHUB_REPO}-${stage}:${rstudio_version}-${debian_version}"
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

# Install GitHub API shell script 'ok.sh' and its dependencies.
# Environment variable GITHUB_TOKEN needs to be set.
function install_github_api() {
  sudo apt-get install -y curl jq
  version='0.5.1'
  curl -LO "https://github.com/whiteinge/ok.sh/archive/${version}.tar.gz"
  tar xzf "${version}.tar.gz"
  mv "ok.sh-${version}/ok.sh" .

  touch ~/.netrc
  chmod 600 ~/.netrc
  cat - > ~/.netrc << EOF
machine api.github.com
    login $GITHUB_USER
    password $GITHUB_TOKEN

machine uploads.github.com
    login $GITHUB_USER
    password $GITHUB_TOKEN
EOF
}

# Create a draft release on GitHub.
function create_github_release() {
  local -r tag="$1"
  shift

  echo "Creating $tag release on GitHub."
  ./ok.sh -j create_release \
    "$GITHUB_USER" \
    "$GITHUB_REPO" \
    "$tag" \
    name="Version ${tag//v/}" \
    body="* describe\n* what's\n* new" \
    draft=true \
    > release.json

  # Upload all assets.
  local -r upload_url=$(jq -r '.upload_url' release.json | sed 's/{.*$//')
  for stage in 'server-deb' 'desktop-deb'; do
    for debian_version in "$@"; do
      # shellcheck disable=SC2155
      local image_name="$(docker_image_name "${stage}")"
      docker image prune -a -f > /dev/null
      docker pull "$image_name"
      # Extract Debian package.
      docker image save "$image_name" \
        | tar xO --wildcards '*/layer.tar' \
        | tar x
      # shellcheck disable=SC2155
      local deb_package=$(ls -1 rstudio-*"${debian_version}"_armhf.deb)
      echo "Uploading Debian Package: $deb_package"
      ./ok.sh -q upload_asset \
        "${upload_url}?name='$deb_package'" \
        "$deb_package" \
        mime_type='application/octet-stream'
      rm -f "$deb_package"
    done
  done
}
