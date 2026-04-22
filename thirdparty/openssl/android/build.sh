#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/openssl/android")"

ARCH=$1; shift
ANDROID_NDK_ROOT=${1:-${ANDROID_NDK_ROOT}}; shift
BUILD_ROOT="${PLATFORM_ROOT}/build-${ARCH}"

if ! [[ $ARCH == "arm64-v8a" || $ARCH == "armeabi-v7a" || $ARCH == "x86" || $ARCH == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '$ARCH'" >&2
  exit 1
fi
if [ ! -f "$ANDROID_NDK_ROOT/ndk-build" ] && [ ! -f "$ANDROID_NDK_ROOT/ndk-build.cmd" ]; then
  echo "ERROR: $ANDROID_NDK_ROOT is not a valid NDK root" >&2
  exit 1
fi

ANDROID_TOOLCHAIN=${ANDROID_TOOLCHAIN:-$(ls "${ANDROID_NDK_ROOT}/toolchains/" | sort -r | head -n 1)}
ANDROID_PREBUILT_TOOLCHAIN_NAME=${ANDROID_PREBUILT_TOOLCHAIN_NAME:-$(ls "${ANDROID_NDK_ROOT}/toolchains/${ANDROID_TOOLCHAIN}/prebuilt" | sort -r | head -n 1)}
ANDROID_TOOLCHAIN_ROOT="${ANDROID_NDK_ROOT}/toolchains/${ANDROID_TOOLCHAIN}/prebuilt/${ANDROID_PREBUILT_TOOLCHAIN_NAME}"
ANDROID_TARGET=${ANDROID_TARGET:-$(ls "${ANDROID_NDK_ROOT}/toolchains/${ANDROID_TOOLCHAIN}/prebuilt/${ANDROID_PREBUILT_TOOLCHAIN_NAME}/bin/aarch64-linux-android"* | sort -r | head -n 1 | sed -E "s/.*android([0-9]+)-.*/\1/")}

echo "Preparing build folder: $BUILD_ROOT"
"${PLATFORM_ROOT}/../download-openssl.sh" "$BUILD_ROOT" || exit 1

CONFIGURE_FLAGS=("${CONFIGURE_FLAGS}")
CONFIGURE_FLAGS+=("no-shared")

CFLAGS=("${CFLAGS}")
CFLAGS+=("-Wno-macro-redefined")

if [[ $ARCH == 'arm64-v8a' ]]; then
  CONFIGURE_FLAGS+=("android-arm64")
elif [[ $ARCH == 'armeabi-v7a' ]]; then
  CONFIGURE_FLAGS+=("android-arm")
elif [[ $ARCH == 'x86' ]]; then
  CONFIGURE_FLAGS+=("android-x86")
  CFLAGS+=("-Wno-atomic-alignment")
elif [[ $ARCH == 'x86_64' ]]; then
  CONFIGURE_FLAGS+=("android-x86_64")
fi
CONFIGURE_FLAGS+=("-D__ANDROID_API__=${ANDROID_TARGET}")

cd "${BUILD_ROOT}"
PATH="${ANDROID_TOOLCHAIN_ROOT}/bin:$PATH" ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" CFLAGS="${CFLAGS[*]}" ./Configure ${CONFIGURE_FLAGS[@]}
PATH="${ANDROID_TOOLCHAIN_ROOT}/bin:$PATH" make
if [ ! -f ${BUILD_ROOT}/libssl.a ]; then
  echo openssl failed to build >&2
  exit 1
fi

rm -rf "${PLATFORM_ROOT}/${ARCH}"
mkdir -p "${PLATFORM_ROOT}/${ARCH}/lib/../include/"
cp "${BUILD_ROOT}"/lib{ssl,crypto}.a "${PLATFORM_ROOT}/${ARCH}/lib/"
cp -r "${BUILD_ROOT}"/include/* "${PLATFORM_ROOT}/${ARCH}/include/"
source "${BUILD_ROOT}/VERSION.dat"
echo "${MAJOR}.${MINOR}.${PATCH}" > "${PLATFORM_ROOT}/${ARCH}/VERSION"
