#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/boost/macosx")"
MIN_VERSION=${MIN_MACOSX_VERSION:-$(xcrun --sdk macosx --show-sdk-version)}
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

ARCH=$1; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
  exit 1
fi

echo "Preparing build folder: $BUILD_ROOT"
"${PLATFORM_ROOT}/../download-boost.sh" "$BUILD_ROOT" || exit 1

cd "$BUILD_ROOT"
./bootstrap.sh "--with-libraries=atomic,chrono,date_time,filesystem,regex,serialization,system,thread,timer,program_options,locale"

CXX_FLAGS=(${CXX_FLAGS})
CXX_FLAGS+=("-target" "${ARCH}-apple-darwin${MIN_VERSION}")
CXX_FLAGS+=("-isysroot" "$SDK_PATH")
CXX_FLAGS+=("-mmacosx-version-min=$MIN_VERSION")
CXX_FLAGS+=("-Wno-enum-constexpr-conversion")
CXX_FLAGS+=("-Wno-deprecated-declarations")
CXX_FLAGS+=("-Wno-deprecated-builtins")
CXX_FLAGS+=("-Wno-deprecated-copy")
CXX_FLAGS+=("-Wno-sign-compare")
CXX_FLAGS+=("-Wno-uninitialized")

LINK_FLAGS=(${LINK_FLAGS})
LINK_FLAGS+=("-target" "${ARCH}-apple-darwin${MIN_VERSION}")
LINK_FLAGS+=("-isysroot" "$SDK_PATH")
LINK_FLAGS+=("-mmacosx-version-min=$MIN_VERSION")

B2_FLAGS=(${B2_FLAGS})
B2_FLAGS+=("variant=release")
B2_FLAGS+=("link=static")
B2_FLAGS+=("toolset=clang")
B2_FLAGS+=("address-model=64")
if [[ $ARCH == 'arm64' ]]; then
  B2_FLAGS+=("abi=aapcs")
  B2_FLAGS+=("architecture=arm")
else
  B2_FLAGS+=("abi=sysv")
  B2_FLAGS+=("architecture=x86")
fi

ICONV_FRAMEWORK="$(realpath "${PROJECT_ROOT}/thirdparty/iconv/macosx/libiconv.xcframework")"
mkdir -p "${BUILD_ROOT}/iconv/lib/../include/"
cp "${ICONV_FRAMEWORK}"/macos-arm64_x86_64/* "${BUILD_ROOT}/iconv/lib/"
cp -r "${ICONV_FRAMEWORK}"/macos-arm64_x86_64/Headers/* "${BUILD_ROOT}/iconv/include/"
B2_FLAGS+=("-sICONV_PATH=${BUILD_ROOT}/iconv")

CXX_FLAGS="${CXX_FLAGS[*]}"
[ -n "$CXX_FLAGS" ] && B2_FLAGS+=("cxxflags=${CXX_FLAGS}")
LINK_FLAGS="${LINK_FLAGS[*]}"
[ -n "$LINK_FLAGS" ] && B2_FLAGS+=("linkflags=${LINK_FLAGS}")

B2_FLAGS+=("--with-atomic")
B2_FLAGS+=("--with-chrono")
B2_FLAGS+=("--with-date_time")
B2_FLAGS+=("--with-filesystem")
B2_FLAGS+=("--with-regex")
B2_FLAGS+=("--with-serialization")
B2_FLAGS+=("--with-system")
B2_FLAGS+=("--with-thread")
B2_FLAGS+=("--with-timer")
B2_FLAGS+=("--with-program_options")
B2_FLAGS+=("--with-locale")

./b2 -d+2 "${B2_FLAGS[@]}"
libtool -static -o "${BUILD_ROOT}/stage/libboost.a" -arch_only ${ARCH} "${BUILD_ROOT}"/stage/lib/libboost_*.a
mkdir -p "${BUILD_ROOT}/stage/include"
cp -r "${BUILD_ROOT}"/boost "${BUILD_ROOT}/stage/include"

if [ ! -f "${BUILD_ROOT}/stage/libboost.a" ]; then
  echo boost failed to build ${ARCH} >&2
  exit 1
fi

${PLATFORM_ROOT}/../get-boost-version.sh "${BUILD_ROOT}" > "${BUILD_ROOT}/stage/VERSION"

echo "boost build is complete"
echo "      lib: '${BUILD_ROOT}/stage/libboost.a'"
echo "  include: '${BUILD_ROOT}/stage/include'"
echo "  version: '${BUILD_ROOT}/stage/VERSION'"
