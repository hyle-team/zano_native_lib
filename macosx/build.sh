ROOT=$(dirname "$(realpath "${0}/..")")
ZANO="${ROOT}/macosx"

BOOST_VERSION=$(cat "${ROOT}/thirdparty/boost/macosx/libboost.xcframework/VERSION")
OPENSSL_VERSION=$(cat "${ROOT}/thirdparty/openssl/macosx/libopenssl.xcframework/VERSION")

MIN_VERSION=$(xcrun --sdk macosx --show-sdk-version)
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
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
  local BUILD_PATH="${ROOT}/macosx/build-${PLATFORM}-${ARCH}"
  echo "Building: $PLATFORM $ARCH in '${BUILD_PATH}'"

  local CMAKE_C_FLAGS=""
  local CMAKE_CXX_FLAGS=""

  CMAKE_CXX_FLAGS+=" -Wno-deprecated-copy"
  CMAKE_CXX_FLAGS+=" -Wno-deprecated-copy-with-user-provided-copy"
  CMAKE_CXX_FLAGS+=" -Wno-unknown-warning-option"
  CMAKE_CXX_FLAGS+=" -Wno-shorten-64-to-32"
  CMAKE_CXX_FLAGS+=" -Wno-deprecated-ofast"
  CMAKE_CXX_FLAGS+=" -Wno-shorten-64-to-32"
  CMAKE_CXX_FLAGS+=" -Wno-inconsistent-missing-override"
  CMAKE_CXX_FLAGS+=" -Wno-deprecated-declarations"
  CMAKE_CXX_FLAGS+=" -Wno-shift-count-overflow"
  CMAKE_CXX_FLAGS+=" -Wno-delete-non-abstract-non-virtual-dtor"
  CMAKE_CXX_FLAGS+=" -Wno-pessimizing-move"
  CMAKE_CXX_FLAGS+=" -Wno-logical-not-parentheses"
  CMAKE_C_FLAGS+=" -Wno-unknown-warning-option"
  CMAKE_C_FLAGS+=" -Wno-shorten-64-to-32"
  CMAKE_C_FLAGS+=" -Wno-deprecated-ofast"

  local IOS_CMAKE_PLATFORM=
  local FRAMEWORK_PLATFORM=
  if [[ $ARCH == 'arm64' ]]; then
    IOS_CMAKE_PLATFORM=MAC_ARM64
    FRAMEWORK_PLATFORM=macos-arm64_x86_64
  else
    IOS_CMAKE_PLATFORM=MAC
    FRAMEWORK_PLATFORM=macos-arm64_x86_64
  fi

  rm -rf "${BUILD_PATH}"
  cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DCMAKE_TOOLCHAIN_FILE="${ROOT}/ios-cmake/ios.toolchain.cmake" \
    -DPLATFORM=${IOS_CMAKE_PLATFORM} \
    -S"${ROOT}/Zano" \
    -B"${BUILD_PATH}" \
    -GXcode \
    -DOPENSSL_INCLUDE_DIR="${ROOT}/thirdparty/openssl/macosx/libopenssl.xcframework/${FRAMEWORK_PLATFORM}/Headers" \
    -DOPENSSL_CRYPTO_LIBRARY="${ROOT}/thirdparty/openssl/macosx/libopenssl.xcframework/${FRAMEWORK_PLATFORM}/libopenssl.a" \
    -DOPENSSL_SSL_LIBRARY="${ROOT}/thirdparty/openssl/macosx/libopenssl.xcframework/${FRAMEWORK_PLATFORM}/libopenssl.a" \
    -DBoost_VERSION="Boost ${BOOST_VERSION}" \
    -DBoost_FATLIB="${ROOT}/thirdparty/boost/macosx/libboost.xcframework/${FRAMEWORK_PLATFORM}/libboost.a" \
    -DBoost_INCLUDE_DIRS="${ROOT}/thirdparty/boost/macosx/libboost.xcframework/${FRAMEWORK_PLATFORM}/Headers/" \
    -DCMAKE_SYSTEM_NAME=Darwin \
    -DCMAKE_MACOSX_BUNDLE=NO \
    -DDEPLOYMENT_TARGET=${MIN_VERSION} \
    -DMACOSX_DEPLOYMENT_TARGET=${MIN_VERSION} \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=${MIN_VERSION} \
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
  if [ ! -f "${BUILD_PATH}/src/Release-/libwallet.a" ]; then
    echo libzano failed to build ${PLATFORM} ${ARCH} >&2
    exit 1
  fi

  libtool -static -o "${BUILD_PATH}/libzano.a" -arch_only ${ARCH} "${BUILD_PATH}/src/Release/"lib{common,crypto,currency_core,wallet}.a "${BUILD_PATH}/contrib/zlib/Release/libz.a"
  if [ $? -ne 0 ]; then
    echo libzano failed to libtool ${PLATFORM} ${ARCH} >&2
    exit 1
  fi
}
BUILD macosx arm64
BUILD macosx x86_64

rm -rf "${ZANO}/build-macosx"
mkdir -p "${ZANO}/build-macosx"
lipo -create "${ZANO}/build-macosx-arm64/libzano.a" "${ZANO}/build-macosx-x86_64/libzano.a" -output "${ZANO}/build-macosx/libzano.a"
if [ $? -ne 0 ]; then
  echo libzano failed to lipo macosx >&2
  exit 1
fi

rm -rf "${ZANO}/build-include"
mkdir -p "${ZANO}/build-include"
cp "${ROOT}"/Zano/src/wallet/*.h "${ZANO}/build-include/"

ZANO_FRAMEWORK="${ZANO}/libzano.xcframework"
rm -rf "${ZANO_FRAMEWORK}"
xcrun xcodebuild -create-xcframework \
  -library "${ZANO}/build-macosx/libzano.a" \
  -headers "${ZANO}/build-include/" \
  -output "${ZANO_FRAMEWORK}"

"${ROOT}/scripts/zano-version.sh" "${ZANO}/build-macosx-arm64" > "${ZANO_FRAMEWORK}/VERSION"


libtool -static -o "${ZANO}/build-macosx-arm64/libzano-plain-wallet.a" -arch_only arm64 "${ZANO}"/build-macosx-arm64/src/Release/lib{common,crypto,currency_core,wallet}.a "${ZANO}/build-macosx-arm64/contrib/zlib/Release/libz.a" "${ROOT}/thirdparty/boost/macosx/libboost.xcframework/macosx-arm64_x86_64/libboost.a" "${ROOT}/thirdparty/openssl/macosx/libopenssl.xcframework/macosx-arm64_x86_64/libopenssl.a"
libtool -static -o "${ZANO}/build-macosx-x86_64/libzano-plain-wallet.a" -arch_only x86_64 "${ZANO}"/build-macosx-x86_64/src/Release/lib{common,crypto,currency_core,wallet}.a "${ZANO}/build-macosx-x86_64/contrib/zlib/Release/libz.a" "${ROOT}/thirdparty/boost/macosx/libboost.xcframework/macosx-arm64_x86_64/libboost.a" "${ROOT}/thirdparty/openssl/macosx/libopenssl.xcframework/macosx-arm64_x86_64/libopenssl.a"
lipo -create "${ZANO}/build-macosx-arm64/libzano-plain-wallet.a" "${ZANO}/build-macosx-x86_64/libzano-plain-wallet.a" -output "${ZANO}/build-macosx/libzano-plain-wallet.a"

rm -rf "${ZANO}/build-plain-wallet-include"
mkdir -p "${ZANO}/build-plain-wallet-include"
cp "${ROOT}"/Zano/src/wallet/plain_wallet_api.h "${ZANO}/build-plain-wallet-include/"

ZANO_PLAIN_WALLET_FRAMEWORK="${ZANO}/libzano-plain-wallet.xcframework"
rm -rf "${ZANO_PLAIN_WALLET_FRAMEWORK}"
xcrun xcodebuild -create-xcframework \
  -library "${ZANO}/build-macosx/libzano-plain-wallet.a" \
  -headers "${ZANO}/build-plain-wallet-include/" \
  -output "${ZANO_PLAIN_WALLET_FRAMEWORK}"

"${ROOT}/scripts/zano-version.sh" "${ZANO}/build-macosx-arm64" > "${ZANO_PLAIN_WALLET_FRAMEWORK}/VERSION"
