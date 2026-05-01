#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../..")"
PLATFORM_ROOT="${PROJECT_ROOT}/build/windows"
. "$PROJECT_ROOT/scripts/windows-bash.sh"

ARCH=$1; shift
BOOST_ROOT="${PROJECT_ROOT}/_install_windows/boost/${ARCH}"
BOOST_VERSION=$(cat "${BOOST_ROOT}/VERSION")
OPENSSL_ROOT="${PROJECT_ROOT}/_install_windows/openssl/${ARCH}"
OPENSSL_VERSION=$(cat "${OPENSSL_ROOT}/VERSION")
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"
TARGET_ROOT="${PROJECT_ROOT}/_install_windows/zano/${ARCH}"

echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "==============================================================================="
echo "Building: '${BUILD_ROOT}'"

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("-S${PROJECT_ROOT}/Zano" "-B${BUILD_ROOT}")
CONFIGURE_FLAGS+=("-Wno-dev")
CONFIGURE_FLAGS+=("-DCMAKE_TOOLCHAIN_FILE=${PLATFORM_ROOT}/windows-toolchain.cmake")
CONFIGURE_FLAGS+=("-DCMAKE_BUILD_TYPE=Release")
CONFIGURE_FLAGS+=("-DOPENSSL_INCLUDE_DIR=${OPENSSL_ROOT}/include")
CONFIGURE_FLAGS+=("-DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_ROOT}/lib/libcrypto.lib")
CONFIGURE_FLAGS+=("-DOPENSSL_SSL_LIBRARY=${OPENSSL_ROOT}/lib/libssl.lib")
CONFIGURE_FLAGS+=("-DBoost_VERSION=Boost ${BOOST_VERSION}")
CONFIGURE_FLAGS+=("-DBoost_NO_SYSTEM_PATHS=ON")
CONFIGURE_FLAGS+=("-DBoost_USE_STATIC_LIBS=ON")
CONFIGURE_FLAGS+=("-DBoost_USE_STATIC_RUNTIME=OFF")
CONFIGURE_FLAGS+=("-DBOOST_ROOT=${BOOST_ROOT}")
CONFIGURE_FLAGS+=("-DBoost_FATLIB=$(echo "${BOOST_ROOT}"/lib/libboost_*.lib | tr ' ' ';')")
CONFIGURE_FLAGS+=("-DBOOST_LIBRARYDIR=${BOOST_ROOT}/lib")
CONFIGURE_FLAGS+=("-DBoost_LIBRARY_DIR=${BOOST_ROOT}/lib")
CONFIGURE_FLAGS+=("-DBoost_LIBRARY_DIRS=${BOOST_ROOT}/lib")
CONFIGURE_FLAGS+=("-DBOOST_INCLUDEDIR=${BOOST_ROOT}/include")
CONFIGURE_FLAGS+=("-DBoost_INCLUDE_DIR=${BOOST_ROOT}/include")
CONFIGURE_FLAGS+=("-DBoost_INCLUDE_DIRS=${BOOST_ROOT}/include")
CONFIGURE_FLAGS+=("-DTESTNET=OFF")
CONFIGURE_FLAGS+=("-DUSE_PCH=ON")
CONFIGURE_FLAGS+=("-DBUILD_TESTS=OFF")
CONFIGURE_FLAGS+=("-DDISABLE_TOR=ON")
[[ $ARCH == x86_64 ]] && CONFIGURE_FLAGS+=("Ax64" "-Thost=x64")
CONFIGURE_FLAGS+=("-GVisual Studio 17 2022")

cmake.exe "${CONFIGURE_FLAGS[@]}"
cmake --build "${BUILD_ROOT}" --config Release
for lib in currency_core common crypto rpc stratum wallet pch; do
  if [ ! -f "${BUILD_ROOT}/src/Release/${lib}.lib" ]; then
    echo libzano failed to build windows ${ARCH} ${lib} >&2
    exit 1
  fi
done

rm -rf "${TARGET_ROOT}"
mkdir -p "${TARGET_ROOT}/lib/../include/../include-plain-wallet/"
cp "${BUILD_ROOT}"/src/Release/{currency_core,common,crypto,rpc,stratum,wallet,pch}.lib "${TARGET_ROOT}/lib/"
cp "${BUILD_ROOT}"/contrib/zlib/Release/zlibstatic.lib "${TARGET_ROOT}/lib/"
cp "${BUILD_ROOT}"/contrib/db/liblmdb/Release/lmdb.lib "${TARGET_ROOT}/lib/"
cp "${BUILD_ROOT}"/contrib/db/libmdbx/Release/mdbx.lib "${TARGET_ROOT}/lib/"
cp "${BUILD_ROOT}"/contrib/ethereum/libethash/Release/ethash.lib "${TARGET_ROOT}/lib/"
cp "${BUILD_ROOT}"/contrib/miniupnp/miniupnpc/Release/miniupnpc.lib "${TARGET_ROOT}/lib/"
cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${TARGET_ROOT}/include/"
cp "${PROJECT_ROOT}"/Zano/src/wallet/plain_wallet_api.h "${TARGET_ROOT}/include-plain-wallet/"

"${PLATFORM_ROOT}/../zano-version.sh" "${BUILD_ROOT}" > "${TARGET_ROOT}/VERSION"
