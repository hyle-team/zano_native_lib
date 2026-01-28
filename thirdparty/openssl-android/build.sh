#!/bin/bash

OPENSSL_VERSION=${OPENSSL_VERSION:-3.1.8}
OPENSSL_TAR_HASH=${OPENSSL_TAR_HASH:-d319da6aecde3aa6f426b44bbf997406d95275c5c59ab6f6ef53caaa079f456f}
OPENSSL_TAR_URL=${OPENSSL_TAR_URL:-https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz}

tar_name=openssl-${OPENSSL_VERSION}.tar.gz
arch=$1; shift
ANDROID_NDK_ROOT=$1; shift
build_dir=build-${arch}

if ! [[ $arch == "arm64-v8a" || $arch == "armeabi-v7a" || $arch == "x86" || $arch == "x86_64" ]]; then
  echo "ERROR: Unsupported architecture: '$arch'" >&2
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

echo "OpenSSL version: $OPENSSL_VERSION"
if [[ ! -e $tar_name ]]; then
  echo "Downloading OpenSSL tarball: '$OPENSSL_TAR_URL'"
  curl -L $OPENSSL_TAR_URL -o $tar_name
fi
result=$(sha256sum ${tar_name} | awk '{ print $1 }')
if [[ $result != $OPENSSL_TAR_HASH ]]; then
  echo "ERROR: OpenSSL tarball does not satisfy provided hash." >&2
  echo " Expected: $OPENSSL_TAR_HASH" >&2
  echo "   Actual: $result" >&2
  echo "Deleting this tarball." >&2
  rm -rf $tar_name
  exit 1
fi

echo "Preparing build folder: $build_dir"
rm -rf $build_dir
mkdir $build_dir
tar -xzf $tar_name -C $build_dir
content=($(ls $build_dir))
if [[ ${#content[@]} -eq 1 ]]; then
  mv ${build_dir}/${content[0]}/* ${build_dir}/
  rm -rf ${build_dir}/${content[0]}
fi
cd $build_dir

function configure() {
  local CONFIGURE_FLAGS=("no-shared")
  local CFLAGS=""
  local CROSS_SYSROOT=""

  CFLAGS+=" -Wno-macro-redefined"
  # with-prefix prepare-android-env
  if [[ $arch == 'arm64-v8a' ]]; then
    CONFIGURE_FLAGS+=("android-arm64")
    CROSS_SYSROOT="aarch64-linux-android"
  elif [[ $arch == 'armeabi-v7a' ]]; then
    CONFIGURE_FLAGS+=("android-arm")
    CROSS_SYSROOT="armv7a-linux-androideabi"
  elif [[ $arch == 'x86' ]]; then
    CONFIGURE_FLAGS+=("android-x86")
    CROSS_SYSROOT="i686-linux-android"
    CFLAGS+=" -Wno-atomic-alignment"
  elif [[ $arch == 'x86_64' ]]; then
    CONFIGURE_FLAGS+=("android-x86_64")
    CROSS_SYSROOT="x86_64-linux-android"
  fi
  CONFIGURE_FLAGS+=("-D__ANDROID_API__=${ANDROID_TARGET}")

  PATH="${ANDROID_TOOLCHAIN_ROOT}/bin:$PATH" ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT" CFLAGS="$CFLAGS" ./Configure ${CONFIGURE_FLAGS[@]}
}
configure
PATH="${ANDROID_TOOLCHAIN_ROOT}/bin:$PATH" make
