#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))

ARCH=$1; shift
BUILD_DIR=build-linux-${ARCH}

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_DIR"
"${SCRIPT_ROOT}/../download-iconv.sh" "$BUILD_DIR" || exit 1
cd $BUILD_DIR

if [[ $ARCH == 'arm64' ]]; then
  LINUX_ARCH="aarch64"
elif [[ $ARCH == 'x86_64' ]]; then
  LINUX_ARCH="x86_64"
fi
HOST_ARCH=$(uname -m)
if [[ $HOST_ARCH == "x86_64" || $HOST_ARCH == "i386" || $HOST_ARCH == "i686" ]]; then
  HOST_ARCH=x86_64
elif [[ $HOST_ARCH == "arm" || $HOST_ARCH == "arm64" || $HOST_ARCH == "aarch64" ]]; then
  HOST_ARCH=arm64
fi

CONFIGURE_FLAGS=(${CONFIGURE_FLAGS})
CFLAGS=(${CFLAGS})

CONFIGURE_FLAGS+=("--enable-static")
CONFIGURE_FLAGS+=("--disable-shared")
CONFIGURE_FLAGS+=("--prefix=$(realpath .)/stage")
CFLAGS+=("-Wno-parentheses-equality")
if [[ $ARCH != $HOST_ARCH ]]; then
  HOST="${LINUX_ARCH}-linux-gnu"
  CONFIGURE_FLAGS+=("--host=${HOST}")
  CONFIGURE_FLAGS+=("--with-sysroot=/urs/${HOST}")
  export AR="${HOST}-${AR:-ar}"
  export RANLIB="${HOST}-${RANLIB:-ranlib}"
  export CC="${HOST}-${CC:-gcc}"
fi

mkdir -p stage
export CFLAGS="${CFLAGS[@]}"
./configure "${CONFIGURE_FLAGS[@]}" || exit 1
make -j$(nproc) install || exit 1
