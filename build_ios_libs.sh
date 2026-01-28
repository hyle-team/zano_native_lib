
if [[ $1 != "silent" ]]; then set -x; else shift; fi


# configuring paths

# Get the full path to the script file
SCRIPT_PATH=$(realpath "$0")

# Extract the directory path
MOBILE_PROJECT_ROOT=$(dirname "$SCRIPT_PATH")


export ZANO_MOBILE_IOS_BOOST_FRAMEWORK="$MOBILE_PROJECT_ROOT/_install_ios/lib/thirdparty/libboost.xcframework"
export ZANO_MOBILE_IOS_BOOST_VERSION_STR="Boost $(cat ${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/VERSION)"

export ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK="$MOBILE_PROJECT_ROOT/_install_ios/lib/thirdparty/libopenssl.xcframework"
export ZANO_MOBILE_IOS_OPENSSL_VERSION=$(cat ${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/VERSION)

export ZANO_PATH="$MOBILE_PROJECT_ROOT/Zano"

export NO_DEFAULT_PATH

echo "Boost:           $ZANO_MOBILE_IOS_BOOST_FRAMEWORK"
echo "Boost Version:   $ZANO_MOBILE_IOS_BOOST_VERSION_STR"
echo "OpenSSL:         $ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK"
echo "OpenSSL Version: $ZANO_MOBILE_IOS_OPENSSL_VERSION"
echo "Native Zano:     $ZANO_PATH"
echo "==============================================================================="
echo "Building..."

echo "Folder is: $ZANO_PATH"
cd "$ZANO_PATH"
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

CONFIG_TYPE="$1"
if [ -z "$CONFIG_TYPE" ]; then
    CONFIG_TYPE="Release"
fi

echo "Config type: $CONFIG_TYPE"

export ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONEOS="$MOBILE_PROJECT_ROOT/_builds_ios/iphoneos"
export ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONESIMULATOR="$MOBILE_PROJECT_ROOT/_builds_ios/iphonesimulator"
export ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64="$MOBILE_PROJECT_ROOT/_builds_ios/arm64"
export ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64="$MOBILE_PROJECT_ROOT/_builds_ios/x86_64"
export ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR="$MOBILE_PROJECT_ROOT/_builds_ios/arm64_simulator"
export ZANO_MOBILE_IOS_FRAMEWORK="$MOBILE_PROJECT_ROOT/_install_ios/lib/libzano.xcframework"
export ZANO_MOBILE_PLAIN_WALLET_IOS_FRAMEWORK="$MOBILE_PROJECT_ROOT/_install_ios/lib/libzano-plain-wallet.xcframework"

export ZANO_MOBILE_IOS_INSTALL_FOLDER="$MOBILE_PROJECT_ROOT/_install_ios"

rm -rf "${ZANO_MOBILE_IOS_INSTALL_FOLDER}/lib/*.xcframework"


#if false; then ###### delete this


echo "Building ARM64...."

rm -rf "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}"
rm -rf "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install"
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}"
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install"

cmake -DCMAKE_BUILD_TYPE=$CONFIG_TYPE \
      -DCMAKE_TOOLCHAIN_FILE="${MOBILE_PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake" \
      -DPLATFORM=OS64 \
      -S"${ZANO_PATH}" \
      -B"${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}" \
      -GXcode \
      -DOPENSSL_INCLUDE_DIR="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64/Headers" \
      -DOPENSSL_CRYPTO_LIBRARY="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64/libopenssl.a" \
      -DOPENSSL_SSL_LIBRARY="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64/libopenssl.a" \
      -DBoost_VERSION="${ZANO_MOBILE_IOS_BOOST_VERSION_STR}" \
      -DBoost_LIBRARY_DIRS="${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64" \
      -DBoost_INCLUDE_DIRS="${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64/Headers" \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_INSTALL_PREFIX="${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install" \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
      -DDISABLE_TOR=TRUE \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=""

#      -DCMAKE_OSX_ARCHITECTURES="arm64"
#      -DCMAKE_IOS_INSTALL_COMBINED=YES

if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

cmake --build "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}" --config $CONFIG_TYPE  --target install -- -j 4
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

libtool -static -o "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install/lib/libzano.a" -arch_only arm64 ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install/lib/lib{common,crypto,currency_core,wallet,z}.a
libtool -static -o "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install/lib/libzano-plain-wallet.a" -arch_only arm64 ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install/lib/lib{common,crypto,currency_core,wallet,z}.a ${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64/libopenssl.a ${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64/libboost.a

#fi  ###### delete this

#############   Build for x86_64    #######################################

#if false; then ###### delete this

echo "Building x86_64...."

rm -rf "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}"
rm -rf "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install"
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}"
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install"

cmake -DCMAKE_BUILD_TYPE=$CONFIG_TYPE \
      -DCMAKE_TOOLCHAIN_FILE="${MOBILE_PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake" \
      -DPLATFORM=SIMULATOR64 \
      -S"${ZANO_PATH}" \
      -B"${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}" \
      -GXcode \
      -DOPENSSL_INCLUDE_DIR="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64/Headers" \
      -DOPENSSL_CRYPTO_LIBRARY="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64_x86_64-simulator/libopenssl.a" \
      -DOPENSSL_SSL_LIBRARY="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64_x86_64-simulator/libopenssl.a" \
      -DBoost_VERSION="${ZANO_MOBILE_IOS_BOOST_VERSION_STR}" \
      -DBoost_LIBRARY_DIRS="${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64_x86_64-simulator" \
      -DBoost_INCLUDE_DIRS="${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64/Headers" \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_INSTALL_PREFIX="${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install" \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
      -DDISABLE_TOR=TRUE \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=""



#       -DCMAKE_OSX_ARCHITECTURES="x86_64" \



#      -DCMAKE_IOS_INSTALL_COMBINED=YES

if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

cmake --build "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}" --config $CONFIG_TYPE  --target install -- -j 4
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

libtool -static -o "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install/lib/libzano.a" -arch_only x86_64 ${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install/lib/lib{common,crypto,currency_core,wallet,z}.a
lipo -thin x86_64 ${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64_x86_64-simulator/libopenssl.a -output "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install/lib/libopenssl.a"
lipo -thin x86_64 ${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64_x86_64-simulator/libboost.a -output "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install/lib/libboost.a"
libtool -static -o "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install/lib/libzano-plain-wallet.a" -arch_only x86_64 ${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install/lib/lib{common,crypto,currency_core,wallet,z,openssl,boost}.a

#fi ###### delete this

#############   Build for arm64_simulator  #######################################

 #if false; then ###### delete this

echo "Building arm64_simulator...."

rm -rf "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}"
rm -rf "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install"
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}"
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install"

cmake -DCMAKE_BUILD_TYPE=$CONFIG_TYPE \
      -DCMAKE_TOOLCHAIN_FILE="${MOBILE_PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake" \
      -DPLATFORM=SIMULATORARM64 \
      -S"${ZANO_PATH}" \
      -B"${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}" \
      -GXcode \
      -DOPENSSL_INCLUDE_DIR="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64/Headers" \
      -DOPENSSL_CRYPTO_LIBRARY="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64_x86_64-simulator/libopenssl.a" \
      -DOPENSSL_SSL_LIBRARY="${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64_x86_64-simulator/libopenssl.a" \
      -DBoost_VERSION="${ZANO_MOBILE_IOS_BOOST_VERSION_STR}" \
      -DBoost_LIBRARY_DIRS="${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64_x86_64-simulator" \
      -DBoost_INCLUDE_DIRS="${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64/Headers" \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_INSTALL_PREFIX="${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install" \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
      -DDISABLE_TOR=TRUE \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
      -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=""



#       -DCMAKE_OSX_ARCHITECTURES="x86_64" \



#      -DCMAKE_IOS_INSTALL_COMBINED=YES

if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

cmake --build "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}" --config $CONFIG_TYPE  --target install -- -j 4
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

libtool -static -o "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install/lib/libzano.a" -arch_only arm64 ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install/lib/lib{common,crypto,currency_core,wallet,z}.a
lipo -thin arm64 ${ZANO_MOBILE_IOS_OPENSSL_FRAMEWORK}/ios-arm64_x86_64-simulator/libopenssl.a -output "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install/lib/libopenssl.a"
lipo -thin arm64 ${ZANO_MOBILE_IOS_BOOST_FRAMEWORK}/ios-arm64_x86_64-simulator/libboost.a -output "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install/lib/libboost.a"
libtool -static -o "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install/lib/libzano-plain-wallet.a" -arch_only arm64 ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install/lib/lib{common,crypto,currency_core,wallet,z,openssl,boost}.a

#fi ###### delete this

rm -rf ${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONEOS}
mkdir -p ${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONEOS}
cp "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install/lib/libzano.a" "${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONEOS}/libzano.a"
cp "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}-install/lib/libzano-plain-wallet.a" "${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONEOS}/libzano-plain-wallet.a"

rm -rf ${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONESIMULATOR}
mkdir -p ${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONESIMULATOR}
lipo -create \
    "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install/lib/libzano.a" \
    "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install/lib/libzano.a" \
    -output "${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONESIMULATOR}/libzano.a"
lipo -create \
    "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}-install/lib/libzano-plain-wallet.a" \
    "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}-install/lib/libzano-plain-wallet.a" \
    -output "${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONESIMULATOR}/libzano-plain-wallet.a"

ZANO_CURRENT_VERSION="$(\
    cat ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}/version/version.h | grep 'define PROJECT_MAJOR_VERSION' | sed 's/.*PROJECT_MAJOR_VERSION "\([^"]*\)"/\1/' \
).$(\
    cat ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}/version/version.h | grep 'define PROJECT_MINOR_VERSION' | sed 's/.*PROJECT_MINOR_VERSION "\([^"]*\)"/\1/' \
).$(\
    cat ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}/version/version.h | grep 'define PROJECT_REVISION' | sed 's/.*PROJECT_REVISION "\([^"]*\)"/\1/' \
).$(\
    cat ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}/version/version.h | grep 'define PROJECT_VERSION_BUILD_NO ' | sed 's/.*PROJECT_VERSION_BUILD_NO \([0-9]*\)/\1/' \
)[$(\
    cat ${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}/version/version.h | grep 'define BUILD_COMMIT_ID' | sed 's/.*BUILD_COMMIT_ID "\([^"]*\)"/\1/' \
)]"

rm -rf ${ZANO_MOBILE_IOS_FRAMEWORK}
ZANO_MOBILE_IOS_LIBZANO_INCLUDE="${MOBILE_PROJECT_ROOT}/_builds_ios/libzano-include"
mkdir -p "${ZANO_MOBILE_IOS_LIBZANO_INCLUDE}"
cp -r "${MOBILE_PROJECT_ROOT}/Zano/src/wallet/" "${ZANO_MOBILE_IOS_LIBZANO_INCLUDE}"
rm "${ZANO_MOBILE_IOS_LIBZANO_INCLUDE}/"*.cpp
xcrun xcodebuild -create-xcframework \
  -library "${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONEOS}/libzano.a" \
  -headers "${ZANO_MOBILE_IOS_LIBZANO_INCLUDE}" \
  -library "${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONESIMULATOR}/libzano.a" \
  -headers "${ZANO_MOBILE_IOS_LIBZANO_INCLUDE}" \
  -output ${ZANO_MOBILE_IOS_FRAMEWORK}
echo "${ZANO_CURRENT_VERSION}" > "${ZANO_MOBILE_IOS_FRAMEWORK}/VERSION"

ZANO_MOBILE_IOS_LIBZANO_PLAIN_WALLET_INCLUDE="${MOBILE_PROJECT_ROOT}/_builds_ios/libzano-plain-wallet-include"
mkdir -p ${ZANO_MOBILE_IOS_LIBZANO_PLAIN_WALLET_INCLUDE}/
cp "${MOBILE_PROJECT_ROOT}/Zano/src/wallet/plain_wallet_api.h" "${ZANO_MOBILE_IOS_LIBZANO_PLAIN_WALLET_INCLUDE}/"
xcrun xcodebuild -create-xcframework \
  -library "${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONEOS}/libzano-plain-wallet.a" \
  -headers "${ZANO_MOBILE_IOS_LIBZANO_PLAIN_WALLET_INCLUDE}/" \
  -library "${ZANO_MOBILE_IOS_BUILD_FOLDER_IPHONESIMULATOR}/libzano-plain-wallet.a" \
  -headers "${ZANO_MOBILE_IOS_LIBZANO_PLAIN_WALLET_INCLUDE}/" \
  -output "${ZANO_MOBILE_PLAIN_WALLET_IOS_FRAMEWORK}"
echo "${ZANO_CURRENT_VERSION}" > "${ZANO_MOBILE_PLAIN_WALLET_IOS_FRAMEWORK}/VERSION"
