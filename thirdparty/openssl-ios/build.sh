#!/bin/bash

OPENSSL_VERSION=${OPENSSL_VERSION:-3.1.8}
OPENSSL_TAR_HASH=${OPENSSL_TAR_HASH:-d319da6aecde3aa6f426b44bbf997406d95275c5c59ab6f6ef53caaa079f456f}
OPENSSL_TAR_URL=${OPENSSL_TAR_URL:-https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz}

tar_name=openssl-${OPENSSL_VERSION}.tar.gz
platform=$1; shift
arch=$1; shift
build_dir=build-${platform}-${arch}

MIN_VERSION=$(xcrun --sdk $platform --show-sdk-version)
SDK_PATH=$(xcrun --sdk $platform --show-sdk-path)

if [[ $platform == "iphoneos" ]]; then
  if ! [[ $arch == "arm64" ]]; then
    echo "ERROR: Unsupported architecture: '${platform}-${arch}'" >&2
    exit 1
  fi
elif [[ $platform == "iphonesimulator" ]]; then
  if ! [[ $arch == "arm64" || $arch == "x86_64" ]]; then
    echo "ERROR: Unsupported architecture: '${platform}-${arch}'" >&2
    exit 1
  fi
else
  echo "ERROR: Unsupported architecture: '${platform}-${arch}'" >&2
  exit 1
fi

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

  CFLAGS+=" -arch ${arch}"
  CFLAGS+=" -isysroot \"${SDK_PATH}\""
  if [[ $platform == 'iphoneos' ]]; then
    CONFIGURE_FLAGS+=" ios64-xcrun"
    CFLAGS+=" -mios-version-min=${MIN_VERSION}"
  elif [[ $platform == 'iphonesimulator' ]]; then
    CONFIGURE_FLAGS+=" iossimulator-xcrun"
    CFLAGS+=" -mios-simulator-version-min=${MIN_VERSION}"
  fi

  CFLAGS="$CFLAGS" ./Configure ${CONFIGURE_FLAGS[@]}
}
configure
make
