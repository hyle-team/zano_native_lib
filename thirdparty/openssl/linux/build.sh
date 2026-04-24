#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/openssl/linux")"
TARGET_ROOT="${PROJECT_ROOT}/_install_linux/openssl/"

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '$ARCH'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_ROOT"
"${PLATFORM_ROOT}/../download-openssl.sh" "$BUILD_ROOT" || exit 1

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

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("no-shared")
CONFIGURE_FLAGS+=("linux-${LINUX_ARCH}")
if [[ $ARCH != $HOST_ARCH ]]; then
  CONFIGURE_FLAGS+=("--cross-compile-prefix=${LINUX_ARCH}-linux-gnu-")
fi

cd "$BUILD_ROOT"
./Configure "${CONFIGURE_FLAGS[@]}" || exit 1
make -j$(nproc) || exit 1
if [ ! -f "${BUILD_ROOT}/libssl.a" ]; then
  echo openssl failed to build >&2
  exit 1
fi

rm -rf "${TARGET_ROOT}/${ARCH}/"
mkdir -p "${TARGET_ROOT}/${ARCH}/lib/../include/"
cp "${BUILD_ROOT}"/lib{ssl,crypto}.a "${TARGET_ROOT}/${ARCH}/lib/"
cp -r "${BUILD_ROOT}"/include/* "${TARGET_ROOT}/${ARCH}/include/"

source "${BUILD_ROOT}/VERSION.dat"
echo "${MAJOR}.${MINOR}.${PATCH}" > "${TARGET_ROOT}/${ARCH}/VERSION"
