#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/boost/linux")"

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_ROOT"
"${PLATFORM_ROOT}/../download-boost.sh" "$BUILD_ROOT" || exit 1

cd "$BUILD_ROOT"
./bootstrap.sh "--with-libraries=atomic,chrono,date_time,filesystem,regex,serialization,system,thread,timer,program_options,locale"

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

CXX_FLAGS=(${CXX_FLAGS})
CXXFLAGS+=("-fPIC")
CXX_FLAGS+=("-Wno-enum-constexpr-conversion")
CXX_FLAGS+=("-Wno-deprecated-declarations")
CXX_FLAGS+=("-Wno-deprecated-builtins")
CXX_FLAGS+=("-Wno-deprecated-copy")
CXX_FLAGS+=("-Wno-sign-compare")
CXX_FLAGS+=("-Wno-uninitialized")

LINK_FLAGS=(${LINK_FLAGS})
if [[ $ARCH != $HOST_ARCH ]]; then
  LINK_FLAGS+=("-L/usr/${LINUX_ARCH}-linux-gnu/lib")
fi

B2_FLAGS=(${B2_FLAGS})
B2_FLAGS+=("link=static")
if [[ $ARCH == 'arm64' ]]; then
  B2_FLAGS+=("abi=aapcs")
  B2_FLAGS+=("architecture=arm")
else
  B2_FLAGS+=("abi=sysv")
  B2_FLAGS+=("architecture=x86")
fi
B2_CXX=${CXX:-g++}
if [[ $ARCH != $HOST_ARCH ]]; then
  B2_CXX=${LINUX_ARCH}-linux-gnu-${B2_CXX}
  B2_FLAGS+=("binary-format=elf")
  B2_FLAGS+=("target-os=linux")
  B2_FLAGS+=("address-model=64")
fi
B2_FLAGS+=("--user-config=../users-config.jam")
B2_FLAGS+=("toolset=gcc-cxx")

ICONV_ROOT="${PROJECT_ROOT}/thirdparty/iconv/linux/${ARCH}"
mkdir -p "${BUILD_ROOT}/iconv/lib/../include/"
cp ${ICONV_ROOT}/lib/libiconv.a "${BUILD_ROOT}/iconv/lib/"
cp ${ICONV_ROOT}/include/* "${BUILD_ROOT}/iconv/include/"
B2_FLAGS+=("-sICONV_PATH=${BUILD_ROOT}/iconv")
B2_FLAGS+=("boost.locale.icu=off" "boost.locale.iconv=on")
CXX_FLAGS+=("-I${BUILD_ROOT}/iconv/include")
LINK_FLAGS+=("-L${BUILD_ROOT}/iconv/lib" "-liconv")

CXX_FLAGS="${CXX_FLAGS[*]}"
[ -n "$CXX_FLAGS" ] && B2_FLAGS+=("cxxflags=${CXX_FLAGS}")
LINK_FLAGS="${LINK_FLAGS[*]}"
[ -n "$LINK_FLAGS" ] && B2_FLAGS+=("linkflags=${LINK_FLAGS}")

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

export CXX=$B2_CXX

./b2 -d+2 "${B2_FLAGS[@]}"
if [ ! -f ${BUILD_ROOT}/stage/lib/libboost_atomic.a ]; then
  echo boost failed to build >&2
  exit 1
fi

rm -rf "${PLATFORM_ROOT}/${ARCH}"
mkdir -p "${PLATFORM_ROOT}/${ARCH}/lib/../include/"
cp -r "${BUILD_ROOT}"/stage/lib/* "${PLATFORM_ROOT}/${ARCH}/lib/"
cp -r "${BUILD_ROOT}/boost" "${PLATFORM_ROOT}/${ARCH}/include/"
"${PLATFORM_ROOT}/../get-boost-version.sh" "${BUILD_ROOT}" > "${PLATFORM_ROOT}/${ARCH}/VERSION"
