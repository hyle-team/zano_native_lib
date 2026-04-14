#!/bin/bash

PROJECT_ROOT=$(realpath "$(dirname $0)/..")
ZANO_ROOT="${PROJECT_ROOT}/linux"

ICONV_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/iconv/linux/VERSION")
BOOST_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/boost/linux/VERSION")
OPENSSL_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/openssl/linux/VERSION")

MAX_TASKS=${MAX_TASKS:-$(nproc)}

echo "iconv Version:   $ICONV_VERSION"
echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "==============================================================================="
echo "Building..."

BUILD_TYPE=$1
if [ -z "$BUILD_TYPE" ]; then
  BUILD_TYPE="Release"
fi
if [[ -z $CC && -z $CXX && $(gcc -dumpversion | cut -d. -f1) -ge 14 ]]; then
  CC=gcc-13
  CXX=g++-13
  echo "CC:  $CC"
  echo "CXX: $CXX"
  echo "==============================================================================="
fi
# some zano contrib requires ld.gold
if ! command -v ld.gold &>/dev/null; then
  echo "error: ld.gold is not available" >&2
fi

rm -rf ${ZANO_ROOT}/lib
rm -rf ${ZANO_ROOT}/include
mkdir -p ${ZANO_ROOT}/include/../lib/arm64/../x86_64
function BUILD() {
  local ARCH=$1
  local BUILD_PATH="${ZANO_ROOT}/build-linux-${ARCH}"
  echo "Building: linux $ARCH in '${BUILD_PATH}'"

  local LINUX_ARCH=""
  if [[ $ARCH == 'arm64' ]]; then
    LINUX_ARCH="aarch64"
  elif [[ $ARCH == 'x86_64' ]]; then
    LINUX_ARCH="x86_64"
  fi

  local CMAKE_C_FLAGS=()
  local CMAKE_CXX_FLAGS=()

  CMAKE_CXX_FLAGS+=("-Wno-deprecated-copy")
  CMAKE_CXX_FLAGS+=("-Wno-enum-constexpr-conversion")
  CMAKE_CXX_FLAGS+=("-Wno-deprecated-copy-with-user-provided-copy")
  CMAKE_CXX_FLAGS+=("-Wno-unknown-warning-option")
  CMAKE_CXX_FLAGS+=("-Wno-shorten-64-to-32")
  CMAKE_CXX_FLAGS+=("-Wno-deprecated-ofast")
  CMAKE_CXX_FLAGS+=("-Wno-shorten-64-to-32")
  CMAKE_CXX_FLAGS+=("-Wno-inconsistent-missing-override")
  CMAKE_CXX_FLAGS+=("-Wno-deprecated-declarations")
  CMAKE_CXX_FLAGS+=("-Wno-shift-count-overflow")
  CMAKE_CXX_FLAGS+=("-Wno-delete-non-abstract-non-virtual-dtor")
  CMAKE_CXX_FLAGS+=("-Wno-pessimizing-move")
  CMAKE_CXX_FLAGS+=("-Wno-logical-not-parentheses")
  CMAKE_CXX_FLAGS+=("-Wno-maybe-uninitialized")
  CMAKE_C_FLAGS+=("-Wno-enum-constexpr-conversion")
  CMAKE_C_FLAGS+=("-Wno-unknown-warning-option")
  CMAKE_C_FLAGS+=("-Wno-shorten-64-to-32")
  CMAKE_C_FLAGS+=("-Wno-deprecated-ofast")
  CMAKE_C_FLAGS+=("-Wno-maybe-uninitialized")

  CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS[*]}"
  CMAKE_C_FLAGS="${CMAKE_C_FLAGS[*]}"
  cmake -S"${PROJECT_ROOT}/Zano" -B"${BUILD_PATH}" \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DOPENSSL_INCLUDE_DIR="${PROJECT_ROOT}/thirdparty/openssl/linux/include/" \
    -DOPENSSL_CRYPTO_LIBRARY="${PROJECT_ROOT}/thirdparty/openssl/linux/lib/${ARCH}/libcrypto.a" \
    -DOPENSSL_SSL_LIBRARY="${PROJECT_ROOT}/thirdparty/openssl/linux/lib/${ARCH}/libssl.a" \
    -DBoost_VERSION="Boost ${BOOST_VERSION}" \
    -DBoost_FATLIB="$(echo "${PROJECT_ROOT}"/thirdparty/boost/linux/lib/${ARCH}/libboost_*.a "${PROJECT_ROOT}"/thirdparty/iconv/linux/lib/${ARCH}/*.a | tr ' ' ';')" \
    -DBoost_INCLUDE_DIRS="${PROJECT_ROOT}/thirdparty/boost/linux/include/" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR=${LINUX_ARCH} \
    -DCMAKE_C_COMPILER=${LINUX_ARCH}-linux-gnu-${CC:-gcc} \
    -DCMAKE_CXX_COMPILER=${LINUX_ARCH}-linux-gnu-${CXX:-g++} \
    -DCMAKE_EXE_LINKER_FLAGS="-L/usr/${LINUX_ARCH}-linux-gnu/lib" \
    -DDISABLE_TOR=TRUE \
    -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}" \
    -DNOT_NEED_LIBM=ON \
    -DLIB_MATH="m" || exit 1

  cmake --build "${BUILD_PATH}" --config ${BUILD_TYPE} -- -j $MAX_TASKS
  if [ ! -f "${BUILD_PATH}/src/libwallet.a" ]; then
    echo libzano failed to build linux ${ARCH} >&2
    exit 1
  fi

  cp "${BUILD_PATH}/src/"lib{common,crypto,currency_core,wallet,rpc,stratum}.a "${ZANO_ROOT}/lib/${ARCH}/"
  cp "${BUILD_PATH}/contrib/zlib/libz.a" "${ZANO_ROOT}/lib/${ARCH}/"
  cp "${BUILD_PATH}/contrib/db/liblmdb/liblmdb.a" "${ZANO_ROOT}/lib/${ARCH}/"
  cp "${BUILD_PATH}/contrib/db/libmdbx/libmdbx.a" "${ZANO_ROOT}/lib/${ARCH}/"
  cp "${BUILD_PATH}/contrib/ethereum/libethash/libethash.a" "${ZANO_ROOT}/lib/${ARCH}/"
  cp "${BUILD_PATH}/contrib/miniupnp/miniupnpc/libminiupnpc.a" "${ZANO_ROOT}/lib/${ARCH}/"
}
BUILD arm64
BUILD x86_64

rm -rf "${ZANO_ROOT}/include"
mkdir -p "${ZANO_ROOT}/include"
cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${ZANO_ROOT}/include/"

"${PROJECT_ROOT}/scripts/zano-version.sh" "${ZANO_ROOT}/build-linux-arm64" > "${ZANO_ROOT}/VERSION"
