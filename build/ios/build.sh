#!/bin/bash

PROJECT_ROOT=$(realpath "$(dirname $0)/..")
ZANO="${PROJECT_ROOT}/ios"

BOOST_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/boost/ios/libboost.xcframework/VERSION")
OPENSSL_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/openssl/ios/libopenssl.xcframework/VERSION")

MAX_TASKS=${MAX_TASKS:-$(sysctl -n hw.logicalcpu)}

echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "==============================================================================="
echo "Building..."

BUILD_TYPE=$1
if [ -z "$BUILD_TYPE" ]; then
  BUILD_TYPE="Release"
fi

function BUILD() {
  local PLATFORM=$1
  local ARCH=$2
  local BUILD_PATH="${PROJECT_ROOT}/ios/build-${PLATFORM}-${ARCH}"
  echo "Building: $PLATFORM $ARCH in '${BUILD_PATH}'"

  local CMAKE_C_FLAGS=()
  local CMAKE_CXX_FLAGS=()

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

  local IOS_CMAKE_PLATFORM=
  local FRAMEWORK_PLATFORM=
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

  MIN_VERSION=${MIN_IOS_VERSION:-$(xcrun --sdk $PLATFORM --show-sdk-version)}

  rm -rf "${BUILD_PATH}"
  CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS[*]}"
  CMAKE_C_FLAGS="${CMAKE_C_FLAGS[*]}"
  cmake -S"${PROJECT_ROOT}/Zano" -B"${BUILD_PATH}" \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DCMAKE_TOOLCHAIN_FILE="${PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake" \
    -DPLATFORM=${IOS_CMAKE_PLATFORM} \
    -DDEPLOYMENT_TARGET=${MIN_VERSION} \
    -GXcode \
    -DOPENSSL_INCLUDE_DIR="${PROJECT_ROOT}/thirdparty/openssl/ios/libopenssl.xcframework/${FRAMEWORK_PLATFORM}/Headers" \
    -DOPENSSL_CRYPTO_LIBRARY="${PROJECT_ROOT}/thirdparty/openssl/ios/libopenssl.xcframework/${FRAMEWORK_PLATFORM}/libopenssl.a" \
    -DOPENSSL_SSL_LIBRARY="${PROJECT_ROOT}/thirdparty/openssl/ios/libopenssl.xcframework/${FRAMEWORK_PLATFORM}/libopenssl.a" \
    -DBoost_VERSION="Boost ${BOOST_VERSION}" \
    -DBoost_FATLIB="${PROJECT_ROOT}/thirdparty/boost/ios/libboost.xcframework/${FRAMEWORK_PLATFORM}/libboost.a" \
    -DBoost_INCLUDE_DIRS="${PROJECT_ROOT}/thirdparty/boost/ios/libboost.xcframework/${FRAMEWORK_PLATFORM}/Headers/" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
    -DDISABLE_TOR=TRUE \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="" \
    -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}"
  if [ $? -ne 0 ]; then
    echo libzano failed to configure ${PLATFORM} ${ARCH} >&2
    exit 1
  fi

  cmake --build "${BUILD_PATH}" --config ${BUILD_TYPE} -- -j $MAX_TASKS
  if [ ! -f "${BUILD_PATH}/src/Release-${PLATFORM}/libwallet.a" ]; then
    echo libzano failed to build ${PLATFORM} ${ARCH} >&2
    exit 1
  fi

  libtool -static -o "${BUILD_PATH}/libzano.a" -arch_only ${ARCH} "${BUILD_PATH}/src/Release-${PLATFORM}/"lib{common,crypto,currency_core,wallet}.a "${BUILD_PATH}/contrib/zlib/Release-${PLATFORM}/libz.a"
  if [ $? -ne 0 ]; then
    echo libzano failed to libtool ${PLATFORM} ${ARCH} >&2
    exit 1
  fi
}

BUILD iphoneos arm64
BUILD iphonesimulator arm64
BUILD iphonesimulator x86_64

rm -rf "${ZANO}/build-iphonesimulator"
mkdir -p "${ZANO}/build-iphonesimulator"
lipo -create "${ZANO}/build-iphonesimulator-arm64/libzano.a" "${ZANO}/build-iphonesimulator-x86_64/libzano.a" -output "${ZANO}/build-iphonesimulator/libzano.a"
if [ $? -ne 0 ]; then
  echo libzano failed to lipo iphonesimulator >&2
  exit 1
fi

rm -rf "${ZANO}/build-include"
mkdir -p "${ZANO}/build-include"
cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${ZANO}/build-include/"

ZANO_FRAMEWORK="${ZANO}/libzano.xcframework"
rm -rf "${ZANO_FRAMEWORK}"
xcrun xcodebuild -create-xcframework \
  -library "${ZANO}/build-iphoneos-arm64/libzano.a" \
  -headers "${ZANO}/build-include/" \
  -library "${ZANO}/build-iphonesimulator/libzano.a" \
  -headers "${ZANO}/build-include/" \
  -output "${ZANO_FRAMEWORK}"

"${PROJECT_ROOT}/scripts/zano-version.sh" "${ZANO}/build-iphoneos-arm64" > "${ZANO_FRAMEWORK}/VERSION"


libtool -static -o "${ZANO}/build-iphoneos-arm64/libzano-plain-wallet.a" -arch_only arm64 "${ZANO}"/build-iphoneos-arm64/src/Release-iphoneos/lib{common,crypto,currency_core,wallet}.a "${ZANO}/build-iphoneos-arm64/contrib/zlib/Release-iphoneos/libz.a" "${PROJECT_ROOT}/thirdparty/boost/ios/libboost.xcframework/ios-arm64/libboost.a" "${PROJECT_ROOT}/thirdparty/openssl/ios/libopenssl.xcframework/ios-arm64/libopenssl.a"
libtool -static -o "${ZANO}/build-iphonesimulator-arm64/libzano-plain-wallet.a" -arch_only arm64 "${ZANO}"/build-iphonesimulator-arm64/src/Release-iphonesimulator/lib{common,crypto,currency_core,wallet}.a "${ZANO}/build-iphonesimulator-arm64/contrib/zlib/Release-iphonesimulator/libz.a" "${PROJECT_ROOT}/thirdparty/boost/ios/libboost.xcframework/ios-arm64_x86_64-simulator/libboost.a" "${PROJECT_ROOT}/thirdparty/openssl/ios/libopenssl.xcframework/ios-arm64_x86_64-simulator/libopenssl.a"
libtool -static -o "${ZANO}/build-iphonesimulator-x86_64/libzano-plain-wallet.a" -arch_only x86_64 "${ZANO}"/build-iphonesimulator-x86_64/src/Release-iphonesimulator/lib{common,crypto,currency_core,wallet}.a "${ZANO}/build-iphonesimulator-x86_64/contrib/zlib/Release-iphonesimulator/libz.a" "${PROJECT_ROOT}/thirdparty/boost/ios/libboost.xcframework/ios-arm64_x86_64-simulator/libboost.a" "${PROJECT_ROOT}/thirdparty/openssl/ios/libopenssl.xcframework/ios-arm64_x86_64-simulator/libopenssl.a"
lipo -create "${ZANO}/build-iphonesimulator-arm64/libzano-plain-wallet.a" "${ZANO}/build-iphonesimulator-x86_64/libzano-plain-wallet.a" -output "${ZANO}/build-iphonesimulator/libzano-plain-wallet.a"

rm -rf "${ZANO}/build-plain-wallet-include"
mkdir -p "${ZANO}/build-plain-wallet-include"
cp "${PROJECT_ROOT}"/Zano/src/wallet/plain_wallet_api.h "${ZANO}/build-plain-wallet-include/"

ZANO_PLAIN_WALLET_FRAMEWORK="${ZANO}/libzano-plain-wallet.xcframework"
rm -rf "${ZANO_PLAIN_WALLET_FRAMEWORK}"
xcrun xcodebuild -create-xcframework \
  -library "${ZANO}/build-iphoneos-arm64/libzano-plain-wallet.a" \
  -headers "${ZANO}/build-plain-wallet-include/" \
  -library "${ZANO}/build-iphonesimulator/libzano-plain-wallet.a" \
  -headers "${ZANO}/build-plain-wallet-include/" \
  -output "${ZANO_PLAIN_WALLET_FRAMEWORK}"

"${PROJECT_ROOT}/scripts/zano-version.sh" "${ZANO}/build-iphoneos-arm64" > "${ZANO_PLAIN_WALLET_FRAMEWORK}/VERSION"
