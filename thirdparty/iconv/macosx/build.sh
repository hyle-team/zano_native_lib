#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/iconv/macosx")"
MIN_VERSION=${MIN_MACOSX_VERSION:-$(xcrun --sdk macosx --show-sdk-version)}
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_ROOT"
"${PLATFORM_ROOT}/../download-iconv.sh" "$BUILD_ROOT" || exit 1

CONFIGURE_FLAGS=(${CONFIGURE_FLAGS})
CFLAGS=(${CFLAGS})

CONFIGURE_FLAGS+=("--enable-static")
CONFIGURE_FLAGS+=("--disable-shared")
CONFIGURE_FLAGS+=("--prefix=$BUILD_ROOT/stage")
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

mkdir -p "$BUILD_ROOT/stage"
cd "$BUILD_ROOT"
CFLAGS="${CFLAGS[*]}" ./configure "${CONFIGURE_FLAGS[@]}" || exit 1
make install || exit 1

if [ ! -f "${BUILD_ROOT}/stage/lib/libiconv.a" ]; then
  echo iconv failed to build ${ARCH} >&2
  exit 1
fi

${PLATFORM_ROOT}/../get-iconv-version.sh "${BUILD_ROOT}" > "${BUILD_ROOT}/stage/VERSION"

echo "iconv build is complete"
echo "      lib: '${BUILD_ROOT}/stage/lib/libiconv.a'"
echo "  include: '${BUILD_ROOT}/stage/include'"
echo "  version: '${BUILD_ROOT}/stage/VERSION'"
