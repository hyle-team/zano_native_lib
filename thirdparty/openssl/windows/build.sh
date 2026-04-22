#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/openssl/windows")"
. "$PROJECT_ROOT/scripts/windows-bash.sh"

ARCH=$1; shift
if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi
BUILD_ROOT=${PLATFORM_ROOT}/build-${ARCH}
TARGET_ROOT="${PLATFORM_ROOT}"/${ARCH}

echo "Preparing build folder: $BUILD_ROOT"
"${PROJECT_ROOT}/thirdparty/openssl/download-openssl.sh" "$BUILD_ROOT" || exit 1
cd "$BUILD_ROOT"

CONFIGURE_FLAGS=(${CONFIGURE_FLAGS})

CONFIGURE_FLAGS+=("no-shared")
CONFIGURE_FLAGS+=("no-tests")
if [[ $ARCH == 'arm64' ]]; then
  CONFIGURE_FLAGS+=("VC-WIN64-ARM")
elif [[ $ARCH == 'x86_64' ]]; then
  CONFIGURE_FLAGS+=("VC-WIN64A")
fi

pwsh -Command "perl Configure ${CONFIGURE_FLAGS[*]}" || exit 1
pwsh -Command "nmake" || exit 1

rm -rf "${TARGET_ROOT}"
mkdir -p "${TARGET_ROOT}/lib/../include/"
cp "${BUILD_ROOT}"/*.lib "${TARGET_ROOT}/lib/"
cp -r "${BUILD_ROOT}"/include/* "${TARGET_ROOT}/include/"

source "${BUILD_ROOT}/VERSION.dat"
echo "${MAJOR}.${MINOR}.${PATCH}" > "${TARGET_ROOT}/VERSION"
