#!/bin/bash

log='/tmp/x.dryrun.log'
fake_docker='/tmp/x.dryrun.bin/docker'

function setup() {
  # Install fake docker command.
  mkdir -p "$(dirname ${fake_docker})"
  printf '#!/bin/bash\necho "would execute: docker $@"\n' > "${fake_docker}"
  chmod 755 "${fake_docker}"
  PATH="$(dirname ${fake_docker}):$PATH"
}

function teardown() {
  rm -f "${log}"
  rm -f "${fake_docker}"
  rmdir "$(dirname ${fake_docker})"
}

function check_num_lines() {
  local -r context=$1
  local -r search=$2
  local -r expected_lines=$3
  local -r actual_lines=$(grep -c "${search}" ${log})
  if [[ "${actual_lines}" -ne "${expected_lines}" ]]; then
    (
      echo "===== begin log ====="
      cat "${log}"
      echo "===== end log ====="
      printf "${context}: Expected %d '${search}' lines, but found %d\n" \
        "${expected_lines}" "${actual_lines}"
    ) 1>&2
    echo 'FAIL'
    exit 1
  fi
}

function run() {
  if ((verbose)); then
    "$@" 2>&1 | tee -a "${log}"
  else
    "$@" >> "${log}" 2>&1
  fi
}

function main() {
  # Scan command line.
  for arg in "$@"; do
    case $arg in
      '-v' | '--verbose') verbose=1 ;;
    esac
  done

  setup

  for builder in ./build.sh ./buildx.sh; do
    rm -f "${log}"
    for debian_version in stretch buster bullseye; do
      for stage in build-env desktop-deb server-deb server; do
        run "${builder}" "${debian_version}" "${stage}"
      done
    done
    # expected:= #debian_versions * #stages
    build_cmd=$(echo ${builder} | grep -Eo '(buildx?)')
    check_num_lines "${builder}" "would execute: docker ${build_cmd} " 12
  done

  rm -f "${log}"
  run ./build-all.sh
  # expected: like above + 2 balenalib bullseye pre-builds
  check_num_lines './build-all.sh' 'would execute: docker build ' 14
  check_num_lines './build-all.sh' 'would execute: docker push ' 12

  teardown

  echo 'PASS'
}

main "$@"
