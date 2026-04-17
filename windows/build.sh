#!/bin/bash

PROJECT_ROOT=$(realpath "$(dirname $0)/..")
ARTIFACTS_ROOT="${PROJECT_ROOT}/windows"

BOOST_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/boost/windows/VERSION")
OPENSSL_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/openssl/windows/VERSION")

echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "==============================================================================="
echo "Building..."

BUILD_TYPE=$1
if [ -z "$BUILD_TYPE" ]; then
  BUILD_TYPE="Release"
fi

function BUILD() {
  local ARCH=$1
  local BUILD_ROOT="${ARTIFACTS_ROOT}/build-windows-${ARCH}"
  echo "Building: windows $ARCH in '${BUILD_ROOT}'"

  local ARCH_ARGS=$([[ $ARCH == x86_64 ]] && echo '-Ax64 -Thost=x64' || exit 1)
  cmake.exe -S"${PROJECT_ROOT}/Zano" -B"${BUILD_ROOT}" \
    -Wno-dev \
    -DCMAKE_TOOLCHAIN_FILE="${ARTIFACTS_ROOT}/windows-toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DOPENSSL_INCLUDE_DIR="${PROJECT_ROOT}/thirdparty/openssl/windows/include" \
    -DOPENSSL_CRYPTO_LIBRARY="${PROJECT_ROOT}/thirdparty/openssl/windows/lib/${ARCH}/libcrypto.lib" \
    -DOPENSSL_SSL_LIBRARY="${PROJECT_ROOT}/thirdparty/openssl/windows/lib/${ARCH}/libssl.lib" \
    -DBoost_VERSION="Boost ${BOOST_VERSION}" \
    -DBoost_NO_SYSTEM_PATHS=ON \
    -DBoost_USE_STATIC_LIBS=ON \
    -DBoost_USE_STATIC_RUNTIME \
    -DBOOST_ROOT="${PROJECT_ROOT}/thirdparty/boost/windows" \
    -DBoost_FATLIB="$(echo "${PROJECT_ROOT}"/thirdparty/boost/windows/lib/${ARCH}/libboost_*.lib | tr ' ' ';')" \
    -DBOOST_LIBRARYDIR="${PROJECT_ROOT}/thirdparty/boost/windows/lib/${ARCH}" \
    -DBoost_LIBRARY_DIR="${PROJECT_ROOT}/thirdparty/boost/windows/lib/${ARCH}" \
    -DBoost_LIBRARY_DIRS="${PROJECT_ROOT}/thirdparty/boost/windows/lib/${ARCH}" \
    -DBOOST_INCLUDEDIR="${PROJECT_ROOT}/thirdparty/boost/windows/include" \
    -DBoost_INCLUDE_DIR="${PROJECT_ROOT}/thirdparty/boost/windows/include" \
    -DBoost_INCLUDE_DIRS="${PROJECT_ROOT}/thirdparty/boost/windows/include" \
    -DTESTNET=FALSE \
    -DUSE_PCH=TRUE \
    -DBUILD_TESTS=FALSE \
    -DDISABLE_TOR=TRUE \
    ${ARCH_ARGS} \
    -G"Visual Studio 17 2022" || exit 1
  cmake --build "${BUILD_ROOT}" --config ${BUILD_TYPE}
  for lib in currency_core common crypto rpc stratum wallet pch; do
    if [ ! -f "${BUILD_ROOT}/src/Release/${lib}.lib" ]; then
      echo libzano failed to build windows ${ARCH} ${lib} >&2
      exit 1
    fi
  done

  rm -rf "${ARTIFACTS_ROOT}"/lib/${ARCH}
  mkdir -p "${ARTIFACTS_ROOT}"/lib/${ARCH}
  cp "${BUILD_ROOT}"/src/Release/{currency_core,common,crypto,rpc,stratum,wallet,pch}.lib "${ARTIFACTS_ROOT}"/lib/${ARCH}/
  cp "${BUILD_ROOT}"/contrib/zlib/Release/zlibstatic.lib "${ARTIFACTS_ROOT}"/lib/${ARCH}/
  cp "${BUILD_ROOT}"/contrib/db/liblmdb/Release/lmdb.lib "${ARTIFACTS_ROOT}"/lib/${ARCH}/
  cp "${BUILD_ROOT}"/contrib/db/libmdbx/Release/mdbx.lib "${ARTIFACTS_ROOT}"/lib/${ARCH}/
  cp "${BUILD_ROOT}"/contrib/ethereum/libethash/Release/ethash.lib "${ARTIFACTS_ROOT}"/lib/${ARCH}/
  cp "${BUILD_ROOT}"/contrib/miniupnp/miniupnpc/Release/miniupnpc.lib "${ARTIFACTS_ROOT}"/lib/${ARCH}/
}
BUILD x86_64
# BUILD arm64

rm -rf "${ARTIFACTS_ROOT}"/include
mkdir -p "${ARTIFACTS_ROOT}"/include/
cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${ARTIFACTS_ROOT}/include/"

"${PROJECT_ROOT}/scripts/zano-version.sh" "${ARTIFACTS_ROOT}/build-windows-arm64" > "${ARTIFACTS_ROOT}/VERSION"
