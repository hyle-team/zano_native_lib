
set -x #echo on


# configuring paths

# Get the full path to the script file
SCRIPT_PATH=$(realpath "$0")

# Extract the directory path
MOBILE_PROJECT_ROOT=$(dirname "$SCRIPT_PATH")

export ZANO_MOBILE_IOS_BOOST_VERSION_STR="Boost 1.76.0"

export ZANO_MOBILE_IOS_BOOST_ROOT="$MOBILE_PROJECT_ROOT/_libs_ios/boost"
export ZANO_MOBILE_IOS_BOOST_INCLUDE_PATH="$ZANO_MOBILE_IOS_BOOST_ROOT/include"
# this path is not actually used for linking, in that case it more just to confuse cmake and let it go
export ZANO_MOBILE_IOS_BOOST_LIBRARY_PATH="$MOBILE_PROJECT_ROOT/_libs_ios/boost/lib"
export ZANO_OPENSSL_ROOT="$MOBILE_PROJECT_ROOT/_libs_ios/OpenSSL"

export ZANO_PATH="$MOBILE_PROJECT_ROOT/zano"

export NO_DEFAULT_PATH

echo "Boost Version:  $ZANO_MOBILE_IOS_BOOST_VERSION_STR"
echo "Boost Include:  $ZANO_MOBILE_IOS_BOOST_LIBRARY_PATH"
echo "Boost Lib:      $ZANO_MOBILE_IOS_BOOST_INCLUDE_PATH"
echo "Native Zano:    $ZANO_PATH"
echo "OpenSSL:        $OPENSSL_CRYPTO_LIBRARY"
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


export ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64="$MOBILE_PROJECT_ROOT/_builds_ios/arm64"
export ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64="$MOBILE_PROJECT_ROOT/_install_ios/arm64"
export ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64="$MOBILE_PROJECT_ROOT/_builds_ios/x86_64"
export ZANO_MOBILE_IOS_INSTALL_FOLDER_x86_64="$MOBILE_PROJECT_ROOT/_install_ios/x86_64"
export ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR="$MOBILE_PROJECT_ROOT/_builds_ios/arm64_simulator"
export ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64_SIMULATOR="$MOBILE_PROJECT_ROOT/_install_ios/arm64_simulator"


export ZANO_MOBILE_IOS_INSTALL_FOLDER="$MOBILE_PROJECT_ROOT/_install_ios"

rm -r "${ZANO_MOBILE_IOS_INSTALL_FOLDER}/lib"

#if false; then ###### delete this


echo "Building ARM64...."

export OPENSSL_INCLUDE_DIR="$ZANO_OPENSSL_ROOT/iphoneos/include"
export OPENSSL_CRYPTO_LIBRARY="$ZANO_OPENSSL_ROOT/iphoneos/lib/libcrypto.a"
export OPENSSL_SSL_LIBRARY="$ZANO_OPENSSL_ROOT/iphoneos/lib/libssl.a"

rm -r "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}"          #  ../_builds_ios
rm -r "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}"                         #../_install_ios
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}"
mkdir -p "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}"

cmake -DCMAKE_BUILD_TYPE=$CONFIG_TYPE \
      -DCMAKE_TOOLCHAIN_FILE="${MOBILE_PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake" \
      -DPLATFORM=OS64 \
      -S"${ZANO_PATH}" \
      -B"${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}" \
      -GXcode \
      -DOPENSSL_INCLUDE_DIR="${OPENSSL_INCLUDE_DIR}" \
      -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_CRYPTO_LIBRARY}" \
      -DOPENSSL_SSL_LIBRARY="${OPENSSL_SSL_LIBRARY}" \
      -DBoost_VERSION="${ZANO_MOBILE_IOS_BOOST_VERSION_STR}" \
      -DBoost_LIBRARY_DIRS="${ZANO_MOBILE_IOS_BOOST_LIBRARY_PATH}" \
      -DBoost_INCLUDE_DIRS="${ZANO_MOBILE_IOS_BOOST_INCLUDE_PATH}" \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_INSTALL_PREFIX="${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}" \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
      -DDISABLE_TOR=TRUE 

#      -DCMAKE_OSX_ARCHITECTURES="arm64" 
#      -DCMAKE_IOS_INSTALL_COMBINED=YES 

if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

cmake --build "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64}" --config Release  --target install -- -j 4
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

#fi  ###### delete this

#############   Build for x86_64    #######################################

#if false; then ###### delete this

echo "Building x86_64...."

export OPENSSL_INCLUDE_DIR="$ZANO_OPENSSL_ROOT/iphonesimulator/include"
export OPENSSL_CRYPTO_LIBRARY="$ZANO_OPENSSL_ROOT/iphonesimulator/lib/libcrypto.a"
export OPENSSL_SSL_LIBRARY="$ZANO_OPENSSL_ROOT/iphonesimulator/lib/libssl.a"

rm -r "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}"                           #../_builds_ios
rm -r "${ZANO_MOBILE_IOS_INSTALL_FOLDER_x86_64}"                         #../_install_ios
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}"
mkdir -p "${ZANO_MOBILE_IOS_INSTALL_FOLDER_x86_64}"

cmake -DCMAKE_BUILD_TYPE=$CONFIG_TYPE \
      -DCMAKE_TOOLCHAIN_FILE="${MOBILE_PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake" \
      -DPLATFORM=SIMULATOR64 \
      -S"${ZANO_PATH}" \
      -B"${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}" \
      -GXcode \
      -DOPENSSL_INCLUDE_DIR="${OPENSSL_INCLUDE_DIR}" \
      -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_CRYPTO_LIBRARY}" \
      -DOPENSSL_SSL_LIBRARY="${OPENSSL_SSL_LIBRARY}" \
      -DBoost_VERSION="${ZANO_MOBILE_IOS_BOOST_VERSION_STR}" \
      -DBoost_LIBRARY_DIRS="${ZANO_MOBILE_IOS_BOOST_LIBRARY_PATH}" \
      -DBoost_INCLUDE_DIRS="${ZANO_MOBILE_IOS_BOOST_INCLUDE_PATH}" \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_INSTALL_PREFIX="${ZANO_MOBILE_IOS_INSTALL_FOLDER_x86_64}" \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
      -DDISABLE_TOR=TRUE 


#       -DCMAKE_OSX_ARCHITECTURES="x86_64" \



#      -DCMAKE_IOS_INSTALL_COMBINED=YES 

if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

cmake --build "${ZANO_MOBILE_IOS_BUILD_FOLDER_x86_64}" --config Release  --target install -- -j 4
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

#fi ###### delete this

#############   Build for arm64_simulator  #######################################

if false; then ###### delete this

echo "Building arm64_simulator...."

export OPENSSL_INCLUDE_DIR="$ZANO_OPENSSL_ROOT/iphonesimulator/include"
export OPENSSL_CRYPTO_LIBRARY="$ZANO_OPENSSL_ROOT/iphonesimulator/lib/libcrypto.a"
export OPENSSL_SSL_LIBRARY="$ZANO_OPENSSL_ROOT/iphonesimulator/lib/libssl.a"

rm -r "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}"                           #../_builds_ios
rm -r "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64_SIMULATOR}"                         #../_install_ios
mkdir -p "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}"
mkdir -p "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64_SIMULATOR}"

cmake -DCMAKE_BUILD_TYPE=$CONFIG_TYPE \
      -DCMAKE_TOOLCHAIN_FILE="${MOBILE_PROJECT_ROOT}/ios-cmake/ios.toolchain.cmake" \
      -DPLATFORM=SIMULATORARM64 \
      -S"${ZANO_PATH}" \
      -B"${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}" \
      -GXcode \
      -DOPENSSL_INCLUDE_DIR="${OPENSSL_INCLUDE_DIR}" \
      -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_CRYPTO_LIBRARY}" \
      -DOPENSSL_SSL_LIBRARY="${OPENSSL_SSL_LIBRARY}" \
      -DBoost_VERSION="${ZANO_MOBILE_IOS_BOOST_VERSION_STR}" \
      -DBoost_LIBRARY_DIRS="${ZANO_MOBILE_IOS_BOOST_LIBRARY_PATH}" \
      -DBoost_INCLUDE_DIRS="${ZANO_MOBILE_IOS_BOOST_INCLUDE_PATH}" \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_INSTALL_PREFIX="${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64_SIMULATOR}" \
      -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO \
      -DDISABLE_TOR=TRUE 


#       -DCMAKE_OSX_ARCHITECTURES="x86_64" \



#      -DCMAKE_IOS_INSTALL_COMBINED=YES 

if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

cmake --build "${ZANO_MOBILE_IOS_BUILD_FOLDER_ARM64_SIMULATOR}" --config Release  --target install -- -j 4
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

fi ###### delete this


# due to the conflict between names in openssl/libcrypto.a and zano/libcrypto.a we're renaming our lib before creating xcframowork
mv "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}/lib/libcrypto.a" "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}/lib/libcrypto_.a"
mv "${ZANO_MOBILE_IOS_INSTALL_FOLDER_x86_64}/lib/libcrypto.a" "${ZANO_MOBILE_IOS_INSTALL_FOLDER_x86_64}/lib/libcrypto_.a"


mkdir "${ZANO_MOBILE_IOS_INSTALL_FOLDER}/lib"
libs_list=("libcommon.a" "libwallet.a" "libcrypto_.a" "libcurrency_core.a" "libz.a")

for LIB_NAME in "${libs_list[@]}"
do
    echo "Creating xcframwork for: $LIB_NAME"
    #xcodebuild -create-xcframework -library "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}/lib/$LIB_NAME" -library "${ZANO_MOBILE_IOS_INSTALL_FOLDER_x86_64}/lib/$LIB_NAME"  -library "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64_SIMULATOR}/lib/$LIB_NAME" -output "${ZANO_MOBILE_IOS_INSTALL_FOLDER}/lib/${LIB_NAME}.xcframework"
    xcodebuild -create-xcframework -library "${ZANO_MOBILE_IOS_INSTALL_FOLDER_ARM64}/lib/$LIB_NAME" -library "${ZANO_MOBILE_IOS_INSTALL_FOLDER_x86_64}/lib/$LIB_NAME"  -output "${ZANO_MOBILE_IOS_INSTALL_FOLDER}/lib/${LIB_NAME}.xcframework"
    if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
done

echo "Creating xcframwork for: OpenSSL"
xcodebuild -create-xcframework -library "$ZANO_OPENSSL_ROOT/iphoneos/lib/libcrypto.a" -library "$ZANO_OPENSSL_ROOT/iphonesimulator/lib/libcrypto.a" -output "${ZANO_MOBILE_IOS_INSTALL_FOLDER}/lib/thirdparty/openssl/libcrypto.xcframework"
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi
xcodebuild -create-xcframework -library "$ZANO_OPENSSL_ROOT/iphoneos/lib/libssl.a" -library "$ZANO_OPENSSL_ROOT/iphonesimulator/lib/libssl.a" -output "${ZANO_MOBILE_IOS_INSTALL_FOLDER}/lib/thirdparty/openssl/libssl.xcframework"
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

echo "Creating xcframwork for: Boost"
xcodebuild -create-xcframework -library "${ZANO_MOBILE_IOS_BOOST_ROOT}/stage/iphoneos/libboost.a" -library "${ZANO_MOBILE_IOS_BOOST_ROOT}/stage/iphonesimulator/libboost.a" -output "${ZANO_MOBILE_IOS_INSTALL_FOLDER}/lib/thirdparty/libboost.xcframework"
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi




