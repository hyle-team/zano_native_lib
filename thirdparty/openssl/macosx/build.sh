#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
OPENSSL=$(realpath ${ROOT}/thirdparty/openssl/macosx)

cd "${OPENSSL}"

./builder.sh arm64 || exit 1
if [ ! -f build-macosx-arm64/libssl.a ]; then
  echo openssl failed to build macosx-arm64 >&2
  exit 1
fi
libtool -static -o build-macosx-arm64/libopenssl.a -arch_only arm64 build-macosx-arm64/libssl.a build-macosx-arm64/libcrypto.a

./builder.sh x86_64 || exit 1
if [ ! -f build-macosx-x86_64/libssl.a ]; then
  echo openssl failed to build macosx-x86_64 >&2
  exit 1
fi
libtool -static -o build-macosx-x86_64/libopenssl.a -arch_only x86_64 build-macosx-x86_64/libssl.a build-macosx-x86_64/libcrypto.a

mkdir build-macosx
lipo -create build-macosx-*/libopenssl.a -output build-macosx/libopenssl.a

OPENSSL_FRAMEWORK="${OPENSSL}/libopenssl.xcframework"
rm -rf "${OPENSSL_FRAMEWORK}"
xcrun xcodebuild -create-xcframework \
  -library build-macosx/libopenssl.a \
  -headers build-macosx-arm64/include \
  -output "${OPENSSL_FRAMEWORK}"

source build-macosx-arm64/VERSION.dat
echo "${MAJOR}.${MINOR}.${PATCH}" > "${OPENSSL_FRAMEWORK}/VERSION"
