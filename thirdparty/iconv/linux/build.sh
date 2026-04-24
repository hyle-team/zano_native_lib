#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/iconv/linux")"
TARGET_ROOT="${PROJECT_ROOT}/_install_linux/iconv/"

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_ROOT"
"${PLATFORM_ROOT}/../download-iconv.sh" "$BUILD_ROOT" || exit 1

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
CONFIGURE_FLAGS+=("--enable-static")
CONFIGURE_FLAGS+=("--disable-shared")
CONFIGURE_FLAGS+=("--prefix=${BUILD_ROOT}/stage")
if [[ $ARCH != $HOST_ARCH ]]; then
  HOST="${LINUX_ARCH}-linux-gnu"
  CONFIGURE_FLAGS+=("--host=${HOST}")
  CONFIGURE_FLAGS+=("--with-sysroot=/usr/${HOST}")
  export AR="${HOST}-${AR:-ar}"
  export RANLIB="${HOST}-${RANLIB:-ranlib}"
  export CC="${HOST}-${CC:-gcc}"
fi

CFLAGS=(${CFLAGS})
CFLAGS+=("-Wno-parentheses-equality")
export CFLAGS="${CFLAGS[*]}"

cd "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}/stage"
./configure "${CONFIGURE_FLAGS[@]}" || exit 1
make -j$(nproc) install || exit 1

if [ ! -f "${BUILD_ROOT}/stage/lib/libiconv.a" ]; then
  echo iconv failed to build ${ARCH} >&2
  exit 1
fi

rm -rf "${TARGET_ROOT}/${ARCH}"
mkdir -p "${TARGET_ROOT}/${ARCH}/lib/../include/"
cp "${BUILD_ROOT}"/stage/lib/libiconv.a "${TARGET_ROOT}/${ARCH}/lib/"
cp -r "${BUILD_ROOT}"/include/*.h "${TARGET_ROOT}/${ARCH}/include/"
"${PLATFORM_ROOT}/../get-iconv-version.sh" "${BUILD_ROOT}" > "${TARGET_ROOT}/${ARCH}/VERSION"
