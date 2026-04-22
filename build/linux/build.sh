#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../..")"
PLATFORM_ROOT="${PROJECT_ROOT}/build/linux"

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

ICONV_ROOT="${PROJECT_ROOT}/thirdparty/iconv/linux/${ARCH}"
ICONV_VERSION=$(cat "${ICONV_ROOT}/VERSION")
BOOST_ROOT="${PROJECT_ROOT}/thirdparty/boost/linux/${ARCH}"
BOOST_VERSION=$(cat "${BOOST_ROOT}/VERSION")
OPENSSL_ROOT="${PROJECT_ROOT}/thirdparty/openssl/linux/${ARCH}"
OPENSSL_VERSION=$(cat "${OPENSSL_ROOT}/VERSION")

echo "iconv Version:   $ICONV_VERSION"
echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "==============================================================================="
echo "Building linux $ARCH in '${BUILD_ROOT}..."

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

LINUX_ARCH=""
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

CMAKE_C_FLAGS=("${C_FLAGS}")
CMAKE_CXX_FLAGS=("${CXX_FLAGS}")

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

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("-S${PROJECT_ROOT}/Zano" "-B${BUILD_ROOT}")
CONFIGURE_FLAGS+=("-Wno-dev")
CONFIGURE_FLAGS+=("-DCMAKE_BUILD_TYPE=Release")
CONFIGURE_FLAGS+=("-DOPENSSL_INCLUDE_DIR=${OPENSSL_ROOT}/include/")
CONFIGURE_FLAGS+=("-DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_ROOT}/lib/libcrypto.a")
CONFIGURE_FLAGS+=("-DOPENSSL_SSL_LIBRARY=${OPENSSL_ROOT}/lib/libssl.a")
CONFIGURE_FLAGS+=("-DBoost_VERSION=Boost ${BOOST_VERSION}")
CONFIGURE_FLAGS+=("-DBoost_FATLIB=$(echo "${BOOST_ROOT}"/lib/libboost_*.a "${ICONV_ROOT}"/lib/*.a | tr ' ' ';')")
CONFIGURE_FLAGS+=("-DBoost_INCLUDE_DIRS=${BOOST_ROOT}/include/")
CONFIGURE_FLAGS+=("-DCMAKE_SYSTEM_NAME=Linux")
CONFIGURE_FLAGS+=("-DCMAKE_SYSTEM_PROCESSOR=${LINUX_ARCH}")
if [[ $ARCH != $HOST_ARCH ]]; then
  CONFIGURE_FLAGS+=("-DCMAKE_C_COMPILER=${LINUX_ARCH}-linux-gnu-${CC:-gcc}")
  CONFIGURE_FLAGS+=("-DCMAKE_CXX_COMPILER=${LINUX_ARCH}-linux-gnu-${CXX:-g++}")
fi
CONFIGURE_FLAGS+=("-DDISABLE_TOR=ON")
CONFIGURE_FLAGS+=("-DCMAKE_C_FLAGS=${CMAKE_C_FLAGS[*]}")
CONFIGURE_FLAGS+=("-DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS[*]}")
CONFIGURE_FLAGS+=("-DNOT_NEED_LIBM=ON")
CONFIGURE_FLAGS+=("-DLIB_MATH=m")

CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS[*]}"
CMAKE_C_FLAGS="${CMAKE_C_FLAGS[*]}"

cmake "${CONFIGURE_FLAGS[@]}" || exit 1
cmake --build "${BUILD_ROOT}" --config Release -- -j$(nproc)
if [ ! -f "${BUILD_ROOT}/src/libwallet.a" ]; then
  echo libzano failed to build >&2
  exit 1
fi

rm -rf "${PLATFORM_ROOT}/${ARCH}"
mkdir -p "${PLATFORM_ROOT}/${ARCH}/lib/../include/"
cp "${BUILD_ROOT}/src/"lib{common,crypto,currency_core,wallet,rpc,stratum}.a "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/contrib/zlib/libz.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/contrib/db/liblmdb/liblmdb.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/contrib/db/libmdbx/libmdbx.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/contrib/ethereum/libethash/libethash.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/contrib/miniupnp/miniupnpc/libminiupnpc.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${PLATFORM_ROOT}/${ARCH}/include/"
"${PLATFORM_ROOT}/../zano-version.sh" "${BUILD_ROOT}" > "${PLATFORM_ROOT}/${ARCH}/VERSION"
