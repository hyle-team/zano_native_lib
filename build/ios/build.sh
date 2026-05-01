#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../..")"
PLATFORM_ROOT="${PROJECT_ROOT}/build/ios"

BOOST_FRAMEWORK="${PROJECT_ROOT}/_install_ios/lib/thirdparty/libboost.xcframework"
BOOST_VERSION=$(cat "${BOOST_FRAMEWORK}/VERSION")
OPENSSL_FRAMEWORK="${PROJECT_ROOT}/_install_ios/lib/thirdparty/libopenssl.xcframework"
OPENSSL_VERSION=$(cat "${OPENSSL_FRAMEWORK}/VERSION")

PLATFORM=$1; shift
ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${PLATFORM}-${ARCH}"
MIN_VERSION=${MIN_IOS_VERSION:-$(xcrun --sdk $PLATFORM --show-sdk-version)}

echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "==============================================================================="
echo "Building $PLATFORM $ARCH in '${BUILD_ROOT}..."

CMAKE_C_FLAGS=("${C_FLAGS}")
CMAKE_CXX_FLAGS=("${CXX_FLAGS}")

CMAKE_CXX_FLAGS+=("-Wno-deprecated-copy")
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
CMAKE_C_FLAGS+=("-Wno-unknown-warning-option")
CMAKE_C_FLAGS+=("-Wno-shorten-64-to-32")
CMAKE_C_FLAGS+=("-Wno-deprecated-ofast")

IOS_CMAKE_PLATFORM=
FRAMEWORK_PLATFORM=
if [[ $PLATFORM == 'iphoneos' ]]; then
  IOS_CMAKE_PLATFORM=OS64
  FRAMEWORK_PLATFORM=ios-arm64
elif [[ $ARCH == 'arm64' ]]; then
  IOS_CMAKE_PLATFORM=SIMULATORARM64
  FRAMEWORK_PLATFORM=ios-arm64_x86_64-simulator
else
  IOS_CMAKE_PLATFORM=SIMULATOR64
  FRAMEWORK_PLATFORM=ios-arm64_x86_64-simulator
fi

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("-S${PROJECT_ROOT}/Zano" "-B${BUILD_ROOT}")
CONFIGURE_FLAGS+=("-Wno-dev")
CONFIGURE_FLAGS+=("-DCMAKE_BUILD_TYPE=Release")
CONFIGURE_FLAGS+=("-DCMAKE_TOOLCHAIN_FILE=${PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake")
CONFIGURE_FLAGS+=("-DPLATFORM=${IOS_CMAKE_PLATFORM}")
CONFIGURE_FLAGS+=("-DDEPLOYMENT_TARGET=${MIN_VERSION}")
CONFIGURE_FLAGS+=("-GXcode")
CONFIGURE_FLAGS+=("-DOPENSSL_INCLUDE_DIR=${OPENSSL_FRAMEWORK}/${FRAMEWORK_PLATFORM}/Headers")
CONFIGURE_FLAGS+=("-DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_FRAMEWORK}/${FRAMEWORK_PLATFORM}/libopenssl.a")
CONFIGURE_FLAGS+=("-DOPENSSL_SSL_LIBRARY=${OPENSSL_FRAMEWORK}/${FRAMEWORK_PLATFORM}/libopenssl.a")
CONFIGURE_FLAGS+=("-DBoost_VERSION=Boost ${BOOST_VERSION}")
CONFIGURE_FLAGS+=("-DBoost_FATLIB=${BOOST_FRAMEWORK}/${FRAMEWORK_PLATFORM}/libboost.a")
CONFIGURE_FLAGS+=("-DBoost_INCLUDE_DIRS=${BOOST_FRAMEWORK}/${FRAMEWORK_PLATFORM}/Headers/")
CONFIGURE_FLAGS+=("-DCMAKE_SYSTEM_NAME=iOS")
CONFIGURE_FLAGS+=("-DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO")
CONFIGURE_FLAGS+=("-DDISABLE_TOR=ON")
CONFIGURE_FLAGS+=("-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO")
CONFIGURE_FLAGS+=("-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO")
CONFIGURE_FLAGS+=("-DCMAKE_C_FLAGS=${CMAKE_C_FLAGS[*]}")
CONFIGURE_FLAGS+=("-DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS[*]}")

rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"
cmake "${CONFIGURE_FLAGS[@]}" || exit 1
cmake --build "${BUILD_ROOT}" --config Release -- -j $(sysctl -n hw.logicalcpu)
if [ ! -f "${BUILD_ROOT}/src/Release-${PLATFORM}/libwallet.a" ]; then
  echo libzano failed to build ${PLATFORM} ${ARCH} >&2
  exit 1
fi

mkdir -p "${BUILD_ROOT}/stage"
libtool -static -o "${BUILD_ROOT}/stage/libzano.a" -arch_only ${ARCH} \
  "${BUILD_ROOT}/src/Release-${PLATFORM}/"lib{common,crypto,currency_core,wallet}.a \
  "${BUILD_ROOT}/contrib/zlib/Release-${PLATFORM}/libz.a" || exit 1
libtool -static -o "${BUILD_ROOT}/stage/libzano-plain-wallet.a" -arch_only ${ARCH} \
  "${BUILD_ROOT}/stage/libzano.a" \
  "${OPENSSL_FRAMEWORK}/${FRAMEWORK_PLATFORM}/libopenssl.a" \
  "${BOOST_FRAMEWORK}/${FRAMEWORK_PLATFORM}/libboost.a"

mkdir -p "${BUILD_ROOT}/stage/include"
cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${BUILD_ROOT}/stage/include/"

mkdir -p "${BUILD_ROOT}/stage/include-plain-wallet"
cp "${PROJECT_ROOT}"/Zano/src/wallet/plain_wallet_api.h "${BUILD_ROOT}/stage/include-plain-wallet/"

"${PLATFORM_ROOT}/../zano-version.sh" "${BUILD_ROOT}" > "${BUILD_ROOT}/stage/VERSION"
