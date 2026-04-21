#!/bin/bash

PROJECT_ROOT=$(realpath $(dirname $0)/../../..)
PLATFORM_ROOT=$(realpath "${PROJECT_ROOT}/thirdparty/boost/windows")
. $PROJECT_ROOT/scripts/windows-bash.sh

ARCH=$1; shift
if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"
TARGET_ROOT="${PLATFORM_ROOT}/${ARCH}"

echo "Preparing build folder: $BUILD_ROOT"
"${PROJECT_ROOT}/thirdparty/boost/download-boost.sh" "$BUILD_ROOT" || exit 1
cd "$BUILD_ROOT"

pwsh -Command ".\\bootstrap.bat --with-libraries=atomic,chrono,date_time,filesystem,regex,serialization,system,thread,timer,program_options,locale,log" || exit 1

CXX_FLAGS=(${CXX_FLAGS})

B2_FLAGS=(${B2_FLAGS})
B2_FLAGS+=("link=static")
B2_FLAGS+=("toolset=msvc")
B2_FLAGS+=("variant=release")
B2_FLAGS+=("threading=multi")
B2_FLAGS+=("runtime-link=shared")
B2_FLAGS+=("address-model=64")
if [[ $ARCH == 'arm64' ]]; then
  B2_FLAGS+=("architecture=arm")
else
  B2_FLAGS+=("architecture=x86")
fi
CXX_FLAGS="${CXX_FLAGS[*]}"
[ -n "$CXX_FLAGS" ] && B2_FLAGS+=("cxxflags=${CXX_FLAGS}")
B2_FLAGS+=("--with-atomic")
B2_FLAGS+=("--with-chrono")
B2_FLAGS+=("--with-date_time")
B2_FLAGS+=("--with-filesystem")
B2_FLAGS+=("--with-regex")
B2_FLAGS+=("--with-serialization")
B2_FLAGS+=("--with-system")
B2_FLAGS+=("--with-thread")
B2_FLAGS+=("--with-timer")
B2_FLAGS+=("--with-program_options")
B2_FLAGS+=("--with-locale")
B2_FLAGS+=("--with-log")

pwsh -Command ".\\b2.exe ${B2_FLAGS[*]}" stage || exit 1

rm -rf "${TARGET_ROOT}"
mkdir -p "${TARGET_ROOT}/lib/../include"
cp "${BUILD_ROOT}"/stage/lib/*.lib "${TARGET_ROOT}/lib/"
cp -r "${BUILD_ROOT}/boost" "${TARGET_ROOT}/include/"

${PROJECT_ROOT}/thirdparty/boost/get-boost-version.sh "${BUILD_ROOT}" > "${TARGET_ROOT}/VERSION"
