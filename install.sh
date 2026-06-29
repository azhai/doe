#!/bin/bash

# FIND: v0.4
TAG=0.3
if [[ "$@" != "" ]]
then
  TAG="$@"
fi

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# First check OS.
OS="$(uname)"
if [[ "${OS}" == "Linux" ]]
then
  DOE_LINUX=1
  DOE_PATH=/usr/local/bin
elif [[ "${OS}" == "Darwin" ]]
then
  DOE_MACOS=1
  DOE_PATH=/usr/local/bin
else
  abort "Install is only supported on macOS and Linux."
fi

# Required installation paths.
if [[ -n "${DOE_MACOS}" ]]
then
  UNAME_MACHINE="$(/usr/bin/uname -m)"
  if [[ "${UNAME_MACHINE}" == "arm64" ]]
  then
    DOE_BUNDLE="https://github.com/azhai/doe/releases/download/${TAG}/doe-macos-arm64.tar.gz"
  else
    DOE_BUNDLE="https://github.com/azhai/doe/releases/download/${TAG}/doe-macos-x64.tar.gz"
  fi
else
  UNAME_MACHINE="$(uname -m)"
  DOE_BUNDLE="https://github.com/azhai/doe/releases/download/${TAG}/doe-linux-x64.tar.gz"
fi

sudo sh -c "mkdir -p ${DOE_PATH}; \
    echo 'Downloading ${DOE_BUNDLE}.'; \
    curl -fsSL $DOE_BUNDLE | tar -xz -C $DOE_PATH; \
    chmod a+x ${DOE_PATH}/doe; \
    echo 'Installed to ${DOE_PATH}/doe.'"
