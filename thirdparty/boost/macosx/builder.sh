#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))

ARCH=$1; shift
BUILD_DIR=build-macosx-${ARCH}

MIN_VERSION=$(xcrun --sdk macosx --show-sdk-version)
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

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

CXX_FLAGS=(${CXX_FLAGS})
CXX_FLAGS+=("-target ${ARCH}-apple-darwin${MIN_VERSION}")
CXX_FLAGS+=("-isysroot \"$SDK_PATH\"")
CXX_FLAGS+=("-mmacosx-version-min=$MIN_VERSION")
CXX_FLAGS+=("-Wno-enum-constexpr-conversion")
CXX_FLAGS+=("-Wno-deprecated-declarations")
CXX_FLAGS+=("-Wno-deprecated-builtins")
CXX_FLAGS+=("-Wno-deprecated-copy")
CXX_FLAGS+=("-Wno-sign-compare")
CXX_FLAGS+=("-Wno-uninitialized")

LINK_FLAGS=(${LINK_FLAGS})
LINK_FLAGS+=("-target ${ARCH}-apple-darwin${MIN_VERSION}")
LINK_FLAGS+=("-isysroot \"$SDK_PATH\"")
LINK_FLAGS+=("-mmacosx-version-min=$MIN_VERSION")

B2_FLAGS=(${B2_FLAGS})
B2_FLAGS+=("link=static")
B2_FLAGS+=("toolset=clang")
B2_FLAGS+=("address-model=64")
if [[ $ARCH == 'arm64' ]]; then
  B2_FLAGS+=("abi=aapcs")
  B2_FLAGS+=("architecture=arm")
else
  B2_FLAGS+=("abi=sysv")
  B2_FLAGS+=("architecture=x86")
fi
# local ICONV_PATH=$(realpath ${PROJECT_ROOT}/iconv/build-${platform}-${ARCH}/stage)
# report-error $?
# B2_FLAGS+=" -sICONV_PATH=$ICONV_PATH"
CXX_FLAGS="${CXX_FLAGS[*]}"
B2_FLAGS+=("cxxflags=${CXX_FLAGS}")
LINK_FLAGS="${LINK_FLAGS[*]}"
B2_FLAGS+=("linkflags=${LINK_FLAGS}")

# ./b2 -d+2 ${B2_FLAGS} --with-atomic --with-chrono --with-date_time --with-filesystem --with-regex --with-serialization --with-system --with-thread --with-timer --with-program_options --with-locale
./b2 -d+2 "${B2_FLAGS[@]}" --with-atomic --with-chrono --with-date_time --with-filesystem --with-regex --with-serialization --with-system --with-thread --with-timer --with-program_options

libtool -static -o libboost.a -arch_only ${ARCH} stage/lib/libboost_*.a
