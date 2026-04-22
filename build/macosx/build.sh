#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../..")"
PLATFORM_ROOT="${PROJECT_ROOT}/build/macosx"
MIN_VERSION=${MIN_MACOSX_VERSION:-$(xcrun --sdk macosx --show-sdk-version)}
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

ICONV_FRAMEWORK="${PROJECT_ROOT}/thirdparty/iconv/macosx/libiconv.xcframework"
ICONV_VERSION=$(cat "${ICONV_FRAMEWORK}/VERSION")
BOOST_FRAMEWORK="${PROJECT_ROOT}/thirdparty/boost/macosx/libboost.xcframework"
BOOST_VERSION=$(cat "${BOOST_FRAMEWORK}/VERSION")
OPENSSL_FRAMEWORK="${PROJECT_ROOT}/thirdparty/openssl/macosx/libopenssl.xcframework"
OPENSSL_VERSION=$(cat "${OPENSSL_FRAMEWORK}/VERSION")

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

echo "iconv Version:   $ICONV_VERSION"
echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "==============================================================================="
echo "Building macosx $ARCH in '${BUILD_ROOT}..."

C_FLAGS=("${C_FLAGS}")
CXX_FLAGS=("${CXX_FLAGS}")

CXX_FLAGS+=("-Wno-deprecated-copy")
CXX_FLAGS+=("-Wno-enum-constexpr-conversion")
CXX_FLAGS+=("-Wno-deprecated-copy-with-user-provided-copy")
CXX_FLAGS+=("-Wno-unknown-warning-option")
CXX_FLAGS+=("-Wno-shorten-64-to-32")
CXX_FLAGS+=("-Wno-deprecated-ofast")
CXX_FLAGS+=("-Wno-inconsistent-missing-override")
CXX_FLAGS+=("-Wno-deprecated-declarations")
CXX_FLAGS+=("-Wno-shift-count-overflow")
CXX_FLAGS+=("-Wno-delete-non-abstract-non-virtual-dtor")
CXX_FLAGS+=("-Wno-pessimizing-move")
CXX_FLAGS+=("-Wno-logical-not-parentheses")
C_FLAGS+=("-Wno-enum-constexpr-conversion")
C_FLAGS+=("-Wno-unknown-warning-option")
C_FLAGS+=("-Wno-shorten-64-to-32")
C_FLAGS+=("-Wno-deprecated-ofast")

IOS_CMAKE_PLATFORM=
FRAMEWORK_PLATFORM=macos-arm64_x86_64
if [[ $ARCH == 'arm64' ]]; then
  IOS_CMAKE_PLATFORM=MAC_ARM64
else
  IOS_CMAKE_PLATFORM=MAC
fi

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"
libtool -static -o "${BUILD_ROOT}/dependencies.a" -arch_only $ARCH "${BOOST_FRAMEWORK}/${FRAMEWORK_PLATFORM}/libboost.a" "${OPENSSL_FRAMEWORK}/${FRAMEWORK_PLATFORM}/libopenssl.a" "${ICONV_FRAMEWORK}/${FRAMEWORK_PLATFORM}/libiconv.a"

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("-S${PROJECT_ROOT}/Zano")
CONFIGURE_FLAGS+=("-B${BUILD_ROOT}")
CONFIGURE_FLAGS+=("-Wno-dev")
CONFIGURE_FLAGS+=("-DCMAKE_BUILD_TYPE=Release")
CONFIGURE_FLAGS+=("-DCMAKE_TOOLCHAIN_FILE=${PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake")
CONFIGURE_FLAGS+=("-DPLATFORM=${IOS_CMAKE_PLATFORM}")
CONFIGURE_FLAGS+=("-GXcode")
CONFIGURE_FLAGS+=("-DOPENSSL_INCLUDE_DIR=${OPENSSL_FRAMEWORK}/${FRAMEWORK_PLATFORM}/Headers")
CONFIGURE_FLAGS+=("-DOPENSSL_CRYPTO_LIBRARY=${BUILD_ROOT}/dependencies.a")
CONFIGURE_FLAGS+=("-DOPENSSL_SSL_LIBRARY=${BUILD_ROOT}/dependencies.a")
CONFIGURE_FLAGS+=("-DBoost_VERSION=Boost ${BOOST_VERSION}")
CONFIGURE_FLAGS+=("-DBoost_FATLIB=${BUILD_ROOT}/dependencies.a")
CONFIGURE_FLAGS+=("-DBoost_INCLUDE_DIRS=${BOOST_FRAMEWORK}/${FRAMEWORK_PLATFORM}/Headers/")
CONFIGURE_FLAGS+=("-DCMAKE_SYSTEM_NAME=Darwin")
CONFIGURE_FLAGS+=("-DCMAKE_MACOSX_BUNDLE=NO")
CONFIGURE_FLAGS+=("-DDEPLOYMENT_TARGET=${MIN_VERSION}")
CONFIGURE_FLAGS+=("-DMACOSX_DEPLOYMENT_TARGET=${MIN_VERSION}")
CONFIGURE_FLAGS+=("-DCMAKE_OSX_DEPLOYMENT_TARGET=${MIN_VERSION}")
CONFIGURE_FLAGS+=("-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO")
CONFIGURE_FLAGS+=("-DDISABLE_TOR=TRUE")
CONFIGURE_FLAGS+=("-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO")
CONFIGURE_FLAGS+=("-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO")
CONFIGURE_FLAGS+=("-DCMAKE_C_FLAGS=${C_FLAGS[*]}")
CONFIGURE_FLAGS+=("-DCMAKE_CXX_FLAGS=${CXX_FLAGS[*]}")

cmake "${CONFIGURE_FLAGS[@]}" || exit 1
cmake --build "${BUILD_ROOT}" --config Release -- -j $(sysctl -n hw.logicalcpu)
if [ ! -f "${BUILD_ROOT}/src/Release/libwallet.a" ]; then
  echo libzano failed to build >&2
  exit 1
fi

mkdir -p "${BUILD_ROOT}/stage"
libtool -static -o "${BUILD_ROOT}/stage/libzano.a" -arch_only ${ARCH} \
  "${BUILD_ROOT}/src/Release/"lib{common,crypto,currency_core,wallet,rpc,stratum}.a \
  "${BUILD_ROOT}/contrib/zlib/Release/libz.a" \
  "${BUILD_ROOT}/contrib/db/liblmdb/Release/liblmdb.a" \
  "${BUILD_ROOT}/contrib/db/libmdbx/Release/libmdbx.a" \
  "${BUILD_ROOT}/contrib/ethereum/libethash/Release/libethash.a" \
  "${BUILD_ROOT}/contrib/miniupnp/miniupnpc/Release/libminiupnpc.a" || exit 1

mkdir -p "${BUILD_ROOT}/stage/include"
cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${BUILD_ROOT}/stage/include/"

mkdir -p "${BUILD_ROOT}/stage/include-pw"
cp "${PROJECT_ROOT}"/Zano/src/wallet/plain_wallet_api.h "${BUILD_ROOT}/stage/include-pw/"

"${PLATFORM_ROOT}/../zano-version.sh" "${BUILD_ROOT}" > "${BUILD_ROOT}/stage/VERSION"
