#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
ARCH=$1; shift
BUILD_DIR=build-${ARCH}

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '$ARCH'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_DIR"
"${SCRIPT_ROOT}/../download-openssl.sh" "$BUILD_DIR"
cd $BUILD_DIR

CONFIGURE_FLAGS=("no-shared")
CROSS_SYSROOT=""

if [[ $ARCH == 'arm64' ]]; then
  LINUX_ARCH="aarch64"
elif [[ $ARCH == 'x86_64' ]]; then
  LINUX_ARCH="x86_64"
fi
CONFIGURE_FLAGS+=" linux-${LINUX_ARCH}"
CROSS_SYSROOT="${LINUX_ARCH}-linux-gnu"
CONFIGURE_FLAGS+=" --cross-compile-prefix=${LINUX_ARCH}-linux-gnu-"

./Configure ${CONFIGURE_FLAGS[@]}
make
