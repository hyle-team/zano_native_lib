#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
ARCH=$1; shift
BUILD_DIR=build-macosx-${ARCH}

MIN_VERSION=${MIN_MACOSX_VERSION:-$(xcrun --sdk macosx --show-sdk-version)}
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_DIR"
"${SCRIPT_ROOT}/../download-openssl.sh" "$BUILD_DIR" || exit 1
cd $BUILD_DIR

CONFIGURE_FLAGS=("no-shared")
CFLAGS=""

if [[ $ARCH == 'arm64' ]]; then
  CONFIGURE_FLAGS+=" darwin64-arm64"
elif [[ $ARCH == 'x86_64' ]]; then
  CONFIGURE_FLAGS+=" darwin64-x86_64"
fi
CFLAGS+=" -Wno-macro-redefined"
CFLAGS+=" -isysroot \"${SDK_PATH}\""
CFLAGS+=" -mmacosx-version-min=${MIN_VERSION}"

CFLAGS="$CFLAGS" ./Configure ${CONFIGURE_FLAGS[@]}
make
