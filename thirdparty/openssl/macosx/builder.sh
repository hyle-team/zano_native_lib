#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
PLATFORM=$1; shift
ARCH=$1; shift
BUILD_DIR=build-${PLATFORM}-${ARCH}

MIN_VERSION=$(xcrun --sdk $PLATFORM --show-sdk-version)
SDK_PATH=$(xcrun --sdk $PLATFORM --show-sdk-path)

if [[ $PLATFORM != "macosx" ]]; then
  echo "ERROR: Unsupported platform: '${PLATFORM}-${ARCH}'" >&2
  exit 1
fi
if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${PLATFORM}-${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_DIR"
rm -rf $BUILD_DIR
mkdir $BUILD_DIR
cd $BUILD_DIR
"${SCRIPT_ROOT}/../download-openssl.sh"

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
