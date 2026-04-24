#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
OPENSSL=$(realpath ${ROOT}/thirdparty/openssl/ios)
OPENSSL_FRAMEWORK="${OPENSSL}/libopenssl.xcframework"
cd "${OPENSSL}"

./build-arch.sh iphoneos arm64
libtool -static -o build-iphoneos-arm64/libopenssl.a -arch_only arm64 build-iphoneos-arm64/libssl.a build-iphoneos-arm64/libcrypto.a

mkdir build-iphoneos
cp build-iphoneos-arm64/libopenssl.a build-iphoneos/libopenssl.a

./build-arch.sh iphonesimulator arm64
libtool -static -o build-iphonesimulator-arm64/libopenssl.a -arch_only arm64 build-iphonesimulator-arm64/libssl.a build-iphonesimulator-arm64/libcrypto.a

./build-arch.sh iphonesimulator x86_64
libtool -static -o build-iphonesimulator-x86_64/libopenssl.a -arch_only x86_64 build-iphonesimulator-x86_64/libssl.a build-iphonesimulator-x86_64/libcrypto.a

mkdir build-iphonesimulator
lipo -create build-iphonesimulator-*/libopenssl.a -output build-iphonesimulator/libopenssl.a

rm -rf "${OPENSSL_FRAMEWORK}"
xcrun xcodebuild -create-xcframework \
  -library build-iphoneos/libopenssl.a \
  -headers build-iphoneos-arm64/include \
  -library build-iphonesimulator/libopenssl.a \
  -headers build-iphoneos-arm64/include \
  -output "${OPENSSL_FRAMEWORK}"
OPENSSL_CURRENT_VERSION=$(\
  cat build-iphoneos-arm64/VERSION.dat | grep 'MAJOR=' | sed 's/MAJOR=\([^"]*\)/\1/' \
).$(\
  cat build-iphoneos-arm64/VERSION.dat | grep 'MINOR=' | sed 's/MINOR=\([^"]*\)/\1/' \
).$(\
  cat build-iphoneos-arm64/VERSION.dat | grep 'PATCH=' | sed 's/PATCH=\([^"]*\)/\1/' \
)
echo "${OPENSSL_CURRENT_VERSION}" > "${OPENSSL_FRAMEWORK}/VERSION"
