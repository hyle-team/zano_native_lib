ROOT=$(dirname "$(realpath "${0}/..")")
ZANO="${ROOT}/android"

BOOST_VERSION=$(cat "${ROOT}/thirdparty/boost/android/VERSION")
OPENSSL_VERSION=$(cat "${ROOT}/thirdparty/openssl/android/VERSION")
ANDROID_TARGET=${ANDROID_TARGET:-26}

function get_default_max_parallel() {
  case "$(uname -s)" in
    Darwin)  sysctl -n hw.logicalcpu ;;
    Linux)   nproc ;;
    *)       echo "Can not get number of cores on current platform. Use '-j <number>' flag to specify it manually." >&2; exit 1 ;;
  esac
}
MAX_TASKS=${MAX_TASKS:-$(get_default_max_parallel || echo 1)}

echo "Boost Version:   $BOOST_VERSION"
echo "OpenSSL Version: $OPENSSL_VERSION"
echo "Android NDK:     $ANDROID_NDK_ROOT"
echo "Android Target:  $ANDROID_TARGET"
echo "==============================================================================="
echo "Building..."

BUILD_TYPE=$1
if [ -z "$BUILD_TYPE" ]; then
  BUILD_TYPE="Release"
fi

rm -rf "${ZANO}/include/"
rm -rf "${ZANO}/lib/"
mkdir -p "${ZANO}/include/../lib/arm64-v8a/../armeabi-v7a/../x86/../x86_64"
function BUILD() {
  local ARCH=$1
  local BUILD_PATH="${ROOT}/android/build-${ARCH}"
  echo "Building: $ARCH in '${BUILD_PATH}'"

  local CMAKE_C_FLAGS=""
  local CMAKE_CXX_FLAGS=""

  CMAKE_CXX_FLAGS+=" -Wno-deprecated-declarations"
  CMAKE_CXX_FLAGS+=" -Wno-deprecated-copy"
  CMAKE_CXX_FLAGS+=" -Wno-deprecated-copy-with-user-provided-copy"
  CMAKE_CXX_FLAGS+=" -Wno-pessimizing-move"
  CMAKE_CXX_FLAGS+=" -Wno-logical-not-parentheses"
  CMAKE_CXX_FLAGS+=" -Wno-pessimizing-move"
  CMAKE_CXX_FLAGS+=" -Wno-inconsistent-missing-override"
  CMAKE_CXX_FLAGS+=" -Wno-delete-non-abstract-non-virtual-dtor"
  CMAKE_CXX_FLAGS+=" -Wno-logical-not-parentheses"
  CMAKE_CXX_FLAGS+=" -Wno-constant-conversion"
  CMAKE_CXX_FLAGS+=" -Wno-sign-compare"

  if [[ "$ARCH" == "armeabi-v7a" ]]; then
    CMAKE_C_FLAGS+=" -mno-unaligned-access"
    CMAKE_CXX_FLAGS+=" -mno-unaligned-access"
    echo "Applying -mno-unaligned-access for $ARCH"
  fi

  rm -rf "${BUILD_PATH}"
  cmake -S"${ROOT}/Zano" -B"${BUILD_PATH}" \
    -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_SYSTEM_VERSION=$ANDROID_TARGET \
    -DCMAKE_ANDROID_ARCH_ABI=$ARCH \
    -DCMAKE_ANDROID_NDK="${ANDROID_NDK_ROOT}" \
    -DCMAKE_ANDROID_STL_TYPE=c++_static \
    -DDISABLE_TOR=TRUE \
    -DBoost_VERSION="Boost ${BOOST_VERSION}" \
    -DBoost_LIBRARY_DIRS="${ROOT}/thirdparty/boost/android/lib/" \
    -DBoost_INCLUDE_DIRS="${ROOT}/thirdparty/boost/android/include/" \
    -DOPENSSL_INCLUDE_DIR="${ROOT}/thirdparty/openssl/android/include/" \
    -DOPENSSL_CRYPTO_LIBRARY="${ROOT}/thirdparty/openssl/android/lib/${ARCH}/libcrypto.a" \
    -DOPENSSL_SSL_LIBRARY="${ROOT}/thirdparty/openssl/android/lib/${ARCH}/libssl.a" \
    -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}"
  if [ $? -ne 0 ]; then
    echo libzano failed to configure ${ARCH} >&2
    exit 1
  fi

  cmake --build "${BUILD_PATH}" --config ${BUILD_TYPE} -- -j ${MAX_TASKS}
  if [ ! -f "${BUILD_PATH}/src/libwallet.a" ]; then
    echo libzano failed to build ${ARCH} >&2
    exit 1
  fi

  cp "${BUILD_PATH}/src/libcommon.a" "${ZANO}/lib/${ARCH}/"
  cp "${BUILD_PATH}/src/libcrypto.a" "${ZANO}/lib/${ARCH}/"
  cp "${BUILD_PATH}/src/libcurrency_core.a" "${ZANO}/lib/${ARCH}/"
  cp "${BUILD_PATH}/src/libwallet.a" "${ZANO}/lib/${ARCH}/"
  cp "${BUILD_PATH}/contrib/zlib/libz.a" "${ZANO}/lib/${ARCH}/"
}

BUILD arm64-v8a
BUILD armeabi-v7a
BUILD x86
BUILD x86_64
cp "${ROOT}"/Zano/src/wallet/*.h "${ZANO}/include/"
"${ROOT}/scripts/zano-version.sh" "${ZANO}/build-arm64-v8a" > "${ZANO}/VERSION"
