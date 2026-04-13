#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
OPENSSL=$(realpath ${ROOT}/thirdparty/openssl/android)

rm -rf "${OPENSSL}/lib/"
rm -rf "${OPENSSL}/include/"
mkdir -p "${OPENSSL}/include/../lib/arm64-v8a/../armeabi-v7a/../x86/../x86_64"

cd "${OPENSSL}"
for ARCH in arm64-v8a armeabi-v7a x86 x86_64; do
  ANDROID_TARGET=26 ./builder.sh $ARCH "$ANDROID_NDK_ROOT"
  if [ ! -f build-$ARCH/libssl.a ]; then
    echo openssl failed to build >&2
    exit 1
  fi
  cp build-$ARCH/{libssl,libcrypto}.a "${OPENSSL}/lib/$ARCH/"
done
cp -r build-arm64-v8a/include/* "${OPENSSL}/include/"

source build-arm64-v8a/VERSION.dat
echo "${MAJOR}.${MINOR}.${PATCH}" > "${OPENSSL}/VERSION"
