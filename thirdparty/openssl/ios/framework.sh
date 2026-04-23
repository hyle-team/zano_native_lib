#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/openssl/ios")"
FRAMEWORK_ROOT="${PLATFORM_ROOT}/libopenssl.xcframework"

[[ ! -d "${PLATFORM_ROOT}/build-iphoneos-arm64" ]] && "${PLATFORM_ROOT}/build.sh" iphoneos arm64
[[ ! -d "${PLATFORM_ROOT}/build-iphonesimulator-arm64" ]] && "${PLATFORM_ROOT}/build.sh" iphonesimulator arm64
[[ ! -d "${PLATFORM_ROOT}/build-iphonesimulator-x86_64" ]] && "${PLATFORM_ROOT}/build.sh" iphonesimulator x86_64

BUILD_ROOT="${PLATFORM_ROOT}/build-framework"
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}/iphoneos/../iphonesimulator/"
cp "${PLATFORM_ROOT}/build-iphoneos-arm64/libopenssl.a" "${BUILD_ROOT}/iphoneos/"
lipo -create "${PLATFORM_ROOT}"/build-iphonesimulator-{x86_64,arm64}/libopenssl.a -output "${BUILD_ROOT}/iphonesimulator/libopenssl.a"

rm -rf "${FRAMEWORK_ROOT}"
xcodebuild -create-xcframework \
  -library "${BUILD_ROOT}/iphoneos/libopenssl.a" -headers "${PLATFORM_ROOT}/build-iphoneos-arm64/include" \
  -library "${BUILD_ROOT}/iphonesimulator/libopenssl.a" -headers "${PLATFORM_ROOT}/build-iphonesimulator-arm64/include" \
  -output "${FRAMEWORK_ROOT}"
if [ ! -d "${FRAMEWORK_ROOT}" ]; then
  echo OpenSSL failed to create framework >&2
  exit 1
fi
cp "${PLATFORM_ROOT}/build-iphoneos-arm64/VERSION" "${FRAMEWORK_ROOT}/VERSION"

# Backport to old folders
rm -rf "${PROJECT_ROOT}/_install_ios/thirdparty/libopenssl.xcframework"
cp -r "${FRAMEWORK_ROOT}" "${PROJECT_ROOT}/_install_ios/thirdparty/"
