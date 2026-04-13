#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
ARCH=$1; shift
ANDROID_NDK_ROOT=$1; shift
BUILD_DIR=build-${ARCH}

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

echo "Preparing build folder: $BUILD_DIR"
rm -rf $BUILD_DIR
mkdir $BUILD_DIR
cd $BUILD_DIR
"${SCRIPT_ROOT}/../download-openssl.sh"

CONFIGURE_FLAGS=("no-shared")
CFLAGS=""
CROSS_SYSROOT=""

CFLAGS+=" -Wno-macro-redefined"
# with-prefix prepare-android-env
if [[ $ARCH == 'arm64-v8a' ]]; then
  CONFIGURE_FLAGS+=("android-arm64")
  CROSS_SYSROOT="aarch64-linux-android"
elif [[ $ARCH == 'armeabi-v7a' ]]; then
  CONFIGURE_FLAGS+=("android-arm")
  CROSS_SYSROOT="armv7a-linux-androideabi"
elif [[ $ARCH == 'x86' ]]; then
  CONFIGURE_FLAGS+=("android-x86")
  CROSS_SYSROOT="i686-linux-android"
  CFLAGS+=" -Wno-atomic-alignment"
elif [[ $ARCH == 'x86_64' ]]; then
  CONFIGURE_FLAGS+=("android-x86_64")
  CROSS_SYSROOT="x86_64-linux-android"
fi
CONFIGURE_FLAGS+=("-D__ANDROID_API__=${ANDROID_TARGET}")

PATH="${ANDROID_TOOLCHAIN_ROOT}/bin:$PATH" ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" CFLAGS="$CFLAGS" ./Configure ${CONFIGURE_FLAGS[@]}

PATH="${ANDROID_TOOLCHAIN_ROOT}/bin:$PATH" make
