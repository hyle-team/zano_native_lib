#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/openssl/ios")"

PLATFORM=$1; shift
ARCH=$1; shift
MIN_VERSION=${MIN_IOS_VERSION:-$(xcrun --sdk $PLATFORM --show-sdk-version)}
SDK_PATH=$(xcrun --sdk $PLATFORM --show-sdk-path)
BUILD_ROOT="${PLATFORM_ROOT}/build-${PLATFORM}-${ARCH}"

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

echo "Preparing build folder: $BUILD_ROOT"
"${PLATFORM_ROOT}/../download-openssl.sh" "$BUILD_ROOT" || exit 1

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("no-shared")
CFLAGS=("${CFLAGS}")

CFLAGS+=("-arch ${ARCH}")
CFLAGS+=("-isysroot ${SDK_PATH}")
if [[ $PLATFORM == 'iphoneos' ]]; then
  CONFIGURE_FLAGS+=("ios64-xcrun")
  CFLAGS+=("-mios-version-min=${MIN_VERSION}")
elif [[ $PLATFORM == 'iphonesimulator' ]]; then
  CONFIGURE_FLAGS+=("iossimulator-xcrun")
  CFLAGS+=("-mios-simulator-version-min=${MIN_VERSION}")
fi
cd "${BUILD_ROOT}"
CFLAGS="${CFLAGS[*]}" ./Configure "${CONFIGURE_FLAGS[@]}"
make -j $(sysctl -n hw.logicalcpu)
if [ ! -f "${BUILD_ROOT}/libssl.a" ]; then
  echo openssl failed to build >&2
  exit 1
fi
libtool -static -o "${BUILD_ROOT}/libopenssl.a" -arch_only ${ARCH} "${BUILD_ROOT}/libssl.a" "${BUILD_ROOT}/libcrypto.a"

source "${BUILD_ROOT}/VERSION.dat"
echo "${MAJOR}.${MINOR}.${PATCH}" > "${BUILD_ROOT}/VERSION"
