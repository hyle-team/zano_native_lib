#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT=$(realpath ${PROJECT_ROOT}/thirdparty/openssl/macosx)
MIN_VERSION=${MIN_MACOSX_VERSION:-$(xcrun --sdk macosx --show-sdk-version)}
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_ROOT"
"${PLATFORM_ROOT}/../download-openssl.sh" "$BUILD_ROOT" || exit 1

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("no-shared")

if [[ $ARCH == 'arm64' ]]; then
  CONFIGURE_FLAGS+=("darwin64-arm64")
elif [[ $ARCH == 'x86_64' ]]; then
  CONFIGURE_FLAGS+=("darwin64-x86_64")
fi

CFLAGS=("${CFLAGS=""}")
CFLAGS+=("-Wno-macro-redefined")
CFLAGS+=("-isysroot \"${SDK_PATH}\"")
CFLAGS+=("-mmacosx-version-min=${MIN_VERSION}")

cd "${BUILD_ROOT}"
CFLAGS="${CFLAGS[*]}" ./Configure "${CONFIGURE_FLAGS[@]}" || exit 1
make -j$(sysctl -n hw.logicalcpu) || exit 1

if [ ! -f "${BUILD_ROOT}/libssl.a" ]; then
  echo openssl failed to build >&2
  exit 1
fi
libtool -static -o "${BUILD_ROOT}/libopenssl.a" -arch_only ${ARCH} "${BUILD_ROOT}"/lib{ssl,crypto}.a

source "${BUILD_ROOT}/VERSION.dat"
echo "${MAJOR}.${MINOR}.${PATCH}" > "${BUILD_ROOT}/VERSION"

echo "OpenSSL build is complete"
echo "      lib: '${BUILD_ROOT}/libopenssl.a'"
echo "  include: '${BUILD_ROOT}/include'"
echo "  version: '${BUILD_ROOT}/VERSION'"
