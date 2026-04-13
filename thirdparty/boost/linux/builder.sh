#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))

ARCH=$1; shift
BUILD_DIR=build-linux-${ARCH}

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_DIR"
rm -rf $BUILD_DIR
mkdir $BUILD_DIR
cd $BUILD_DIR
"${SCRIPT_ROOT}/../download-boost.sh"

# ./bootstrap.sh "--with-libraries=atomic,chrono,date_time,filesystem,regex,serialization,system,thread,timer,program_options,locale"
./bootstrap.sh "--with-libraries=atomic,chrono,date_time,filesystem,regex,serialization,system,thread,timer,program_options"

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
  CXXFLAGS+=("--sysroot=/usr/${LINUX_ARCH}-linux-gnu/")
fi

LINK_FLAGS=(${LINK_FLAGS})
if [[ $ARCH != $HOST_ARCH ]]; then
  LINK_FLAGS+=("-L/usr/${LINUX_ARCH}-linux-gnu/lib")
  LINK_FLAGS+=("--sysroot=/usr/${LINUX_ARCH}-linux-gnu/")
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

# local ICONV_PATH=$(realpath ${PROJECT_ROOT}/iconv/build-${platform}-${ARCH}/stage)
# report-error $?
# B2_FLAGS+=" -sICONV_PATH=$ICONV_PATH"

CXX_FLAGS="${CXX_FLAGS[*]}"
B2_FLAGS+=("cxxflags=${CXX_FLAGS}")
LINK_FLAGS="${LINK_FLAGS[*]}"
B2_FLAGS+=("linkflags=${LINK_FLAGS}")

# ./b2 -d+2 ${B2_FLAGS} --with-atomic --with-chrono --with-date_time --with-filesystem --with-regex --with-serialization --with-system --with-thread --with-timer --with-program_options --with-locale
CXX=$B2_CXX ./b2 -d+2 "${B2_FLAGS[@]}" --with-atomic --with-chrono --with-date_time --with-filesystem --with-regex --with-serialization --with-system --with-thread --with-timer --with-program_options
