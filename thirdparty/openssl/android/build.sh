#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
OPENSSL=$(realpath ${ROOT}/thirdparty/openssl/android)
rm -rf "${OPENSSL}/lib/"
rm -rf "${OPENSSL}/include/"
mkdir -p "${OPENSSL}/include/../lib/arm64-v8a/../armeabi-v7a/../x86/../x86_64"

cd "${OPENSSL}"
for arch in arm64-v8a armeabi-v7a x86 x86_64; do
  ANDROID_TARGET=26 ./build-arch.sh $arch "$ANDROID_NDK_ROOT"
  cp build-$arch/{libssl,libcrypto}.a "${OPENSSL}/lib/$arch/"
done
cp -r build-arm64-v8a/include/* "${OPENSSL}/include/"
