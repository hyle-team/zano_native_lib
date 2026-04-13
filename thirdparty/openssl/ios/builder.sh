#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
PLATFORM=$1; shift
ARCH=$1; shift
build_dir=build-${PLATFORM}-${ARCH}

MIN_VERSION=$(xcrun --sdk $PLATFORM --show-sdk-version)
SDK_PATH=$(xcrun --sdk $PLATFORM --show-sdk-path)

if [[ $PLATFORM == "iphoneos" ]]; then
  if ! [[ $ARCH == "arm64" ]]; then
    echo "ERROR: Unsupported architecture: '${PLATFORM}-${ARCH}'" >&2
    exit 1
  fi
elif [[ $PLATFORM == "iphonesimulator" ]]; then
  if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
    echo "ERROR: Unsupported architecture: '${PLATFORM}-${ARCH}'" >&2
    exit 1
  fi
else
  echo "ERROR: Unsupported architecture: '${PLATFORM}-${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $build_dir"
rm -rf $build_dir
mkdir $build_dir
cd $build_dir
"${SCRIPT_ROOT}/../download-openssl.sh"

CONFIGURE_FLAGS=("no-shared")
CFLAGS=""

CFLAGS+=" -arch ${ARCH}"
CFLAGS+=" -isysroot \"${SDK_PATH}\""
if [[ $PLATFORM == 'iphoneos' ]]; then
  CONFIGURE_FLAGS+=" ios64-xcrun"
  CFLAGS+=" -mios-version-min=${MIN_VERSION}"
elif [[ $PLATFORM == 'iphonesimulator' ]]; then
  CONFIGURE_FLAGS+=" iossimulator-xcrun"
  CFLAGS+=" -mios-simulator-version-min=${MIN_VERSION}"
fi

CFLAGS="$CFLAGS" ./Configure ${CONFIGURE_FLAGS[@]}
make
