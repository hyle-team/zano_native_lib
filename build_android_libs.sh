set -x #echo on

# configuring paths

# Get the full path to the script file
SCRIPT_PATH=$(realpath "$0")

# Extract the directory path
MOBILE_PROJECT_ROOT=$(dirname "$SCRIPT_PATH")


export ZANO_MOBILE_ANDROID_PROJECT_ROOT="${MOBILE_PROJECT_ROOT}"

export ZANO_MOBILE_ANDROID_BOOST_VERSION_STR="Boost 1.84.0"
export ZANO_MOBILE_ANDROID_BOOST_LIBRARY_PATH="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/_libs_android/boost"
export ZANO_MOBILE_ANDROID_BOOST_INCLUDE_PATH="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/_libs_android/boost/include"
export ZANO_OPENSSL_ROOT_DIR="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/_libs_android/openssl"
export ZANO_PATH="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/Zano"

export ANDROID_NDK_PATH="/Users/${LOGNAME}/Library/Android/sdk/ndk/26.2.11394342"
export ZANO_ANDROID_API_VERSION=23
export ZANO_ANDROID_API_MIN_SDK_VERSION=android-23

echo "Boost Version:  $ZANO_MOBILE_ANDROID_BOOST_VERSION_STR"
echo "Boost Include:  $ZANO_MOBILE_ANDROID_BOOST_INCLUDE_PATH"
echo "Boost Lib:      $ZANO_MOBILE_ANDROID_BOOST_LIBRARY_PATH"
echo "Native Zano:    $ZANO_PATH"
echo "OpenSSL:        $ZANO_OPENSSL_ROOT_DIR"
echo "Android NDK:    $ANDROID_NDK_PATH"
echo "Android API v:  $ZANO_ANDROID_API_VERSION"
echo "==============================================================================="
echo "Building..."


echo "Folder is: $1"


CONFIG_TYPE="$2"
if [ -z "$CONFIG_TYPE" ]; then
    CONFIG_TYPE="Release"
fi

echo "Folder is: $ZANO_PATH"
cd "$ZANO_PATH"

if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

#git pull -r
if [ $? -ne 0 ]; then
    echo "Failed to perform command"
    exit 1
fi

# Define an array of strings
ARCHS_TO_BUILD=("armeabi-v7a" "x86" "arm64-v8a" "x86_64")


export ZANO_ANDROID_LIB_BUILD_PATH="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/_builds_android"
export ZANO_ANDROID_LIB_INSTALL_PATH="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/_install_android"


# Enumerate over the archs
for CURRENT_ARCH_ABI in "${ARCHS_TO_BUILD[@]}"
do
    echo "Building: $CURRENT_ARCH_ABI"

    OPENSSL_INCLUDE_DIR="${ZANO_OPENSSL_ROOT_DIR}/include"
    OPENSSL_CRYPTO_LIBRARY="${ZANO_OPENSSL_ROOT_DIR}/${CURRENT_ARCH_ABI}/lib/libcrypto.a"
    OPENSSL_SSL_LIBRARY="${ZANO_OPENSSL_ROOT_DIR}/${CURRENT_ARCH_ABI}/lib/libssl.a"

    EXTRA_FLAGS=""
    if [ "$CURRENT_ARCH_ABI" = "armeabi-v7a" ]; then
        EXTRA_FLAGS="-DCMAKE_C_FLAGS=-mno-unaligned-access -DCMAKE_CXX_FLAGS=-mno-unaligned-access"
        echo "Applying -mno-unaligned-access for $CURRENT_ARCH_ABI"
    fi

    rm -rf "${ZANO_ANDROID_LIB_BUILD_PATH}"
    cmake -S. -B"${ZANO_ANDROID_LIB_BUILD_PATH}" \
        -DBoost_VERSION="${ZANO_MOBILE_ANDROID_BOOST_VERSION_STR}" \
        -DBoost_LIBRARY_DIRS="${ZANO_MOBILE_ANDROID_BOOST_LIBRARY_PATH}" \
        -DBoost_INCLUDE_DIRS="${ZANO_MOBILE_ANDROID_BOOST_INCLUDE_PATH}" \
        -DCMAKE_BUILD_TYPE=$CONFIG_TYPE \
        -DCMAKE_SYSTEM_NAME=Android \
        -DCMAKE_SYSTEM_VERSION=$ZANO_ANDROID_API_VERSION \
        -DCMAKE_ANDROID_ARCH_ABI=$CURRENT_ARCH_ABI \
        -DCMAKE_ANDROID_NDK="${ANDROID_NDK_PATH}" \
        -DCMAKE_ANDROID_STL_TYPE=c++_static \
        -DDISABLE_TOR=TRUE \
        -DOPENSSL_INCLUDE_DIR="${OPENSSL_INCLUDE_DIR}" \
        -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_CRYPTO_LIBRARY}" \
        -DOPENSSL_SSL_LIBRARY="${OPENSSL_SSL_LIBRARY}" \
        -DCMAKE_INSTALL_PREFIX="${ZANO_ANDROID_LIB_INSTALL_PATH}" \
        -DANDROID_PLATFORM="${ZANO_ANDROID_API_MIN_SDK_VERSION}" \
        ${EXTRA_FLAGS}

    if [ $? -ne 0 ]; then
        echo "Failed to perform command"
        exit 1
    fi

    cmake --build "${ZANO_ANDROID_LIB_BUILD_PATH}" --config Release --target install -- -j 8
    if [ $? -ne 0 ]; then
        echo "Failed to perform command"
        exit 1
    fi


done

echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "        Successfully built all platforms           "
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
