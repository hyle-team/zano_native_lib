#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../..")"
PLATFORM_ROOT="${PROJECT_ROOT}/build/android"
ANDROID_TARGET=${ANDROID_TARGET:-26}

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

BOOST_ROOT="${PROJECT_ROOT}/thirdparty/boost/android/${ARCH}"
BOOST_VERSION=$(cat "${BOOST_ROOT}/VERSION")
OPENSSL_ROOT="${PROJECT_ROOT}/thirdparty/openssl/android/${ARCH}"
OPENSSL_VERSION=$(cat "${OPENSSL_ROOT}/VERSION")

echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "Android NDK:     $ANDROID_NDK_ROOT"
echo "Android Target:  $ANDROID_TARGET"
echo "==============================================================================="
echo "Building android $ARCH in '${BUILD_ROOT}'..."

CMAKE_C_FLAGS=("${C_FLAGS}")
CMAKE_CXX_FLAGS=("${CXX_FLAGS}")

CMAKE_CXX_FLAGS+=("-Wno-deprecated-declarations")
CMAKE_CXX_FLAGS+=("-Wno-deprecated-copy")
CMAKE_CXX_FLAGS+=("-Wno-deprecated-copy-with-user-provided-copy")
CMAKE_CXX_FLAGS+=("-Wno-pessimizing-move")
CMAKE_CXX_FLAGS+=("-Wno-logical-not-parentheses")
CMAKE_CXX_FLAGS+=("-Wno-pessimizing-move")
CMAKE_CXX_FLAGS+=("-Wno-inconsistent-missing-override")
CMAKE_CXX_FLAGS+=("-Wno-delete-non-abstract-non-virtual-dtor")
CMAKE_CXX_FLAGS+=("-Wno-logical-not-parentheses")
CMAKE_CXX_FLAGS+=("-Wno-constant-conversion")
CMAKE_CXX_FLAGS+=("-Wno-sign-compare")
if [[ "$ARCH" == "armeabi-v7a" ]]; then
  CMAKE_C_FLAGS+=("-mno-unaligned-access")
  CMAKE_CXX_FLAGS+=("-mno-unaligned-access")
fi

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("-S${PROJECT_ROOT}/Zano" "-B${BUILD_ROOT}")
CONFIGURE_FLAGS+=("-Wno-dev")
CONFIGURE_FLAGS+=("-DCMAKE_BUILD_TYPE=Release")
CONFIGURE_FLAGS+=("-DCMAKE_SYSTEM_NAME=Android")
CONFIGURE_FLAGS+=("-DCMAKE_SYSTEM_VERSION=$ANDROID_TARGET")
CONFIGURE_FLAGS+=("-DCMAKE_ANDROID_ARCH_ABI=$ARCH")
CONFIGURE_FLAGS+=("-DCMAKE_ANDROID_NDK=${ANDROID_NDK_ROOT}")
CONFIGURE_FLAGS+=("-DCMAKE_ANDROID_STL_TYPE=c++_static")
CONFIGURE_FLAGS+=("-DDISABLE_TOR=TRUE")
CONFIGURE_FLAGS+=("-DBoost_VERSION=Boost ${BOOST_VERSION}")
CONFIGURE_FLAGS+=("-DBoost_LIBRARY_DIRS=${BOOST_ROOT}/lib")
CONFIGURE_FLAGS+=("-DBoost_INCLUDE_DIRS=${BOOST_ROOT}/include/")
CONFIGURE_FLAGS+=("-DOPENSSL_INCLUDE_DIR=${OPENSSL_ROOT}/include/")
CONFIGURE_FLAGS+=("-DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_ROOT}/lib/libcrypto.a")
CONFIGURE_FLAGS+=("-DOPENSSL_SSL_LIBRARY=${OPENSSL_ROOT}/lib/libssl.a")
CONFIGURE_FLAGS+=("-DCMAKE_C_FLAGS=${CMAKE_C_FLAGS[*]}")
CONFIGURE_FLAGS+=("-DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS[*]}")

rm -rf "${BUILD_ROOT}"
cmake "${CONFIGURE_FLAGS[@]}" || exit 1
cmake --build "${BUILD_ROOT}" --config Release
if [ ! -f "${BUILD_ROOT}/src/libwallet.a" ]; then
  echo libzano failed to build ${ARCH} >&2
  exit 1
fi

rm -rf "${PLATFORM_ROOT}/${ARCH}"
mkdir -p "${PLATFORM_ROOT}/${ARCH}/lib/../include/../include-plain-wallet/"
cp "${BUILD_ROOT}/src/libcommon.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/src/libcrypto.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/src/libcurrency_core.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/src/libwallet.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${BUILD_ROOT}/contrib/zlib/libz.a" "${PLATFORM_ROOT}/${ARCH}/lib/"
cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${PLATFORM_ROOT}/${ARCH}/include/"
cp "${PROJECT_ROOT}"/Zano/src/wallet/plain_wallet_api.h "${PLATFORM_ROOT}/${ARCH}/include-plain-wallet/"
"${PLATFORM_ROOT}/../zano-version.sh" "${BUILD_ROOT}" > "${PLATFORM_ROOT}/${ARCH}/VERSION"
