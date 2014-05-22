#!/bin/bash

BPKG_REMOTE="${BPKG_REMOTE:-"https://raw.githubusercontent.com"}"
BPKG_USER="${BPKG_USER:-"bpkg"}"

## outut usage
usage () {
  echo "usage: bpkg-install [-h|--help]"
  echo "   or: bpkg-install <package>"
  echo "   or: bpkg-install <user>/<package>"
}

## Install a bash package
bpkg_install () {
  local pkg="${1}"
  local cwd="`pwd`"
  local user=""
  local name=""
  local url=""
  local uri=""
  local version=""
  local status=""
  local json=""
  declare -a local parts=()
  declare -a local scripts=()

  case "${pkg}" in
    -h|--help)
      usage
      return 0
      ;;
  esac

  ## ensure there is a package to install
  if [ -z "${pkg}" ]; then
    return 1
  fi

  ## ensure remote is reachable
  {
    curl -s "${BPKG_REMOTE}"
    if [ "0" != "$?" ]; then
      return 1
    fi
  }

  ## get version if available
  {
    OLDIFS="${IFS}"
    IFS="@"
    parts=(${pkg})
    IFS="${OLDIFS}"
  }

  if [ "1" = "${#parts[@]}" ]; then
    version="master"
  elif [ "2" = "${#parts[@]}" ]; then
    name="${parts[0]}"
    version="${parts[1]}"
  else
    echo >&2 "error: Error parsing package version"
    return 1
  fi

  ## split by user name and repo
  {
    OLDIFS="${IFS}"
    IFS='/'
    parts=(${pkg})
    IFS="${OLDIFS}"
  }

  if [ "1" = "${#parts[@]}" ]; then
    user="${BPKG_USER}"
    name="${parts[0]}"
  elif [ "2" = "${#parts[@]}" ]; then
    user="${parts[0]}"
    name="${parts[1]}"
  else
    echo >&2 "error: Unable to determine package name"
    return 1
  fi

  ## clean up name of weird trailing versions
  name=${name/@*//}

  ## build uri portion
  uri="/${user}/${name}/${version}"

  ## clean up extra slashes in uri
  uri=${uri/\/\///}

  ## build url
  url="${BPKG_REMOTE}${uri}"

  ## determine if `package.json' exists at url
  {
    status=$(curl -sL "${url}/package.json" -w '%{http_code}' -o /dev/null)
    if [ "0" != "$?" ] || (( status >= 400 )); then
      echo >&2 "error: Package doesn't exist"
      return 1
    fi
  }

  ## read package.json
  json=$(curl -sL "${url}/package.json")

  ## construct scripts array
  {
    scripts=$(echo -n $json | bpkg-json -b | grep 'scripts' | awk '{ print $2 }' | tr -d '"')
    OLDIFS="${IFS}"
    IFS=','
    scripts=($(echo ${scripts}))
    IFS="${OLDIFS}"
  }

  ## get package name from `package.json'
  name="$(echo -n ${json} | bpkg-json -b | grep 'name' | awk '{ print $2 }' | tr -d '\"')"

  if [ "${#scripts[@]}" -gt "0" ]; then
    ## make `deps/' directory if possible
    mkdir -p "${cwd}/deps/${name}"
    ## grab each script and place in deps directory
    for (( i = 0; i < ${#scripts[@]} ; ++i )); do
      (
        local script=${scripts[$i]}
        curl -sL "${url}/${script}" -o "${cwd}/deps/${name}/${script}"
      )
    done
  fi

  return 0
}

if [[ ${BASH_SOURCE[0]} != $0 ]]; then
  export -f bpkg_install
else
  bpkg_install "${@}"
  exit $?
fi