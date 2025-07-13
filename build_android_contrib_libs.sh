set -x #echo on

# configuring paths

# Get the full path to the script file
SCRIPT_PATH=$(realpath "$0")

# Extract the directory path
MOBILE_PROJECT_ROOT=$(dirname "$SCRIPT_PATH")


export ZANO_MOBILE_ANDROID_PROJECT_ROOT="${MOBILE_PROJECT_ROOT}"

export ZANO_MOBILE_ANDROID_BOOST_VERSION_STR_SHORT="1.85.0"
export ZANO_MOBILE_ANDROID_BOOST_VERSION_STR="Boost ${ZANO_MOBILE_ANDROID_BOOST_VERSION_STR_SHORT}"
export ZANO_MOBILE_ANDROID_BOOST_LIBRARY_PATH="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/_libs_android/boost"
export ZANO_MOBILE_ANDROID_BOOST_INCLUDE_PATH="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/_libs_android/boost/include"
export ZANO_OPENSSL_ROOT_DIR="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/_libs_android/openssl"
export ZANO_PATH="${ZANO_MOBILE_ANDROID_PROJECT_ROOT}/Zano"

export ANDROID_NDK_PATH="/Users/${LOGNAME}/Library/Android/sdk/ndk/28.2.13676358"
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


# cd contrib/android/Boost-for-Android
# echo "Folder is: $1"
# ./build-android.sh --boost="${ZANO_MOBILE_ANDROID_BOOST_VERSION_STR_SHORT}" "${ANDROID_NDK_PATH}" --target-version="${ZANO_ANDROID_API_VERSION}" --layout=system --arch="arm64-v8a,armeabi-v7a,x86,x86_64" 



################################################################################

# 1) env -------------------------------------------------------------------
export NDK=$ANDROID_NDK_PATH          # adapt to your path
export HOST_TAG=darwin-x86_64                       # or linux-x86_64 / windows-x86_64
export API=23                                       # minSdkVersion you target

cd contrib/android

# 2) get Boost ----------------------------------------------------------------

wget -qO- https://archives.boost.io/release/1.87.0/source/boost_1_87_0.tar.bz2 | tar xz
cd boost_1_87_0

# 3) create user-config.jam ---------------------------------------------------
cat > tools/build/src/user-config.jam <<EOF
using clang : android_arm64
  : $NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/aarch64-linux-android${API}-clang++
  : <archiver>$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/llvm-ar
    <ranlib>$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/llvm-ranlib
    <compileflags>--target=aarch64-linux-android${API} -fPIC
    <linkflags>--target=aarch64-linux-android${API} -fuse-ld=lld
    <cxxflags>-std=c++17
  ;
EOF

# Repeat the stanza for android_arm (32-bit) or x86_64 if you need them.
# ---------------------------------------------------------------------------

./bootstrap.sh  # generates b2
if [ $? -ne 0 ]; then
    echo "Failed to perform bootstrap"
    exit 1
fi
./b2 -j$(sysctl -n hw.ncpu) \
    --prefix=$PWD/../boost-android/arm64-v8a \
    --with-system --with-filesystem --with-locale --with-thread --with-timer --with-date_time --with-chrono --with-regex --with-serialization --with-atomic --with-program_options \
    toolset=clang-android_arm64 \
    target-os=android \
    link=static \
    threading=multi \
    runtime-link=static \
    install
if [ $? -ne 0 ]; then
    echo "Failed to perform b2"
    exit 1
fi

################################################################################



echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "        Successfully built all platforms           "
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++"
