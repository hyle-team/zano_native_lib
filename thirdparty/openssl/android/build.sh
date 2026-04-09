#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
OPENSSL=$(realpath ${ROOT}/thirdparty/openssl/android)
OPENSSL_VERSION=${OPENSSL_VERSION:-3.1.8}

rm -rf "${OPENSSL}/lib/"
rm -rf "${OPENSSL}/include/"
mkdir -p "${OPENSSL}/include/../lib/arm64-v8a/../armeabi-v7a/../x86/../x86_64"

cd "${OPENSSL}"
for arch in arm64-v8a armeabi-v7a x86 x86_64; do
  ANDROID_TARGET=26 ./build-arch.sh $arch "$ANDROID_NDK_ROOT"
  if [ ! -f build-$arch/libssl.a ]; then
    echo openssl failed to build >&2
    exit 1
  fi
  cp build-$arch/{libssl,libcrypto}.a "${OPENSSL}/lib/$arch/"
done
cp -r build-arm64-v8a/include/* "${OPENSSL}/include/"

echo "${OPENSSL_VERSION}" > "${OPENSSL}/VERSION"
