#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
PROJECT_ROOT=$(realpath ${SCRIPT_ROOT}/../../..)

ARCH=$1; shift
BUILD_DIR=build-linux-${ARCH}

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_DIR"
"${SCRIPT_ROOT}/../download-boost.sh" "$BUILD_DIR" || exit 1
cd $BUILD_DIR

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
CXX_FLAGS+=("-Wno-enum-constexpr-conversion")
CXX_FLAGS+=("-Wno-deprecated-declarations")
CXX_FLAGS+=("-Wno-deprecated-builtins")
CXX_FLAGS+=("-Wno-deprecated-copy")
CXX_FLAGS+=("-Wno-sign-compare")
CXX_FLAGS+=("-Wno-uninitialized")
if [[ $ARCH != $HOST_ARCH ]]; then
  CXXFLAGS+=("-fPIC")
fi

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

ICONV_PATH=$(realpath ${PROJECT_ROOT}/thirdparty/iconv/linux)
mkdir -p ./iconv/include/../lib/../bin/
cp ${ICONV_PATH}/lib/${ARCH}/libiconv.a ./iconv/lib/
cp ${ICONV_PATH}/include/* ./iconv/include/
B2_FLAGS+=("-sICONV_PATH=$(realpath ./iconv)")
B2_FLAGS+=("boost.locale.icu=off" "boost.locale.iconv=on")
CXX_FLAGS+=("-I$(realpath ./iconv/include)")
LINK_FLAGS+=("-L$(realpath ./iconv/lib)" "-liconv")

CXX_FLAGS="${CXX_FLAGS[*]}"
[ -n "$CXX_FLAGS" ] && B2_FLAGS+=("cxxflags=${CXX_FLAGS}")
LINK_FLAGS="${LINK_FLAGS[*]}"
[ -n "$LINK_FLAGS" ] && B2_FLAGS+=("linkflags=${LINK_FLAGS}")

CXX=$B2_CXX ./b2 -d+2 "${B2_FLAGS[@]}" --with-atomic --with-chrono --with-date_time --with-filesystem --with-regex --with-serialization --with-system --with-thread --with-timer --with-program_options --with-locale
