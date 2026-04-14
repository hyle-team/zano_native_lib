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
"${SCRIPT_ROOT}/../download-iconv.sh" "$BUILD_DIR" || exit 1
cd $BUILD_DIR


CONFIGURE_FLAGS=(${CONFIGURE_FLAGS})
CFLAGS=(${CFLAGS})

CONFIGURE_FLAGS+=("--enable-static")
CONFIGURE_FLAGS+=("--disable-shared")
CONFIGURE_FLAGS+=("--prefix=$(realpath .)/stage")
CFLAGS+=("-Wno-parentheses-equality")
if [[ $ARCH == 'arm64' ]]; then
  CONFIGURE_FLAGS+=("--host=aarch64-apple-darwin")
elif [[ $ARCH == 'x86_64' ]]; then
  CONFIGURE_FLAGS+=("--host=x86_64-apple-darwin")
fi
CFLAGS+=("-arch $ARCH")
CFLAGS+=("-mmacosx-version-min=${MIN_VERSION}")
CFLAGS+=("-isysroot ${SDK_PATH}")
CONFIGURE_FLAGS+=("--with-sysroot=${SDK_PATH}")

mkdir -p stage
CFLAGS="${CFLAGS[@]}" ./configure "${CONFIGURE_FLAGS[@]}" || exit 1
make install || exit 1
