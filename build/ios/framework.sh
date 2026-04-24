#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/build/ios")"
TARGET_ROOT="${PROJECT_ROOT}/_install_ios/lib"
FRAMEWORK_ROOT="${TARGET_ROOT}/libzano.xcframework"
FRAMEWORK_PW_ROOT="${TARGET_ROOT}/libzano-plain-wallet.xcframework"

[[ ! -d "${PLATFORM_ROOT}/build-iphoneos-arm64" ]] && "${PLATFORM_ROOT}/build.sh" iphoneos arm64
[[ ! -d "${PLATFORM_ROOT}/build-iphonesimulator-arm64" ]] && "${PLATFORM_ROOT}/build.sh" iphonesimulator arm64
[[ ! -d "${PLATFORM_ROOT}/build-iphonesimulator-x86_64" ]] && "${PLATFORM_ROOT}/build.sh" iphonesimulator x86_64

BUILD_ROOT="${PLATFORM_ROOT}/build-framework"
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}/iphoneos/../iphonesimulator/"
cp "${PLATFORM_ROOT}/build-iphoneos-arm64/stage/libzano.a" "${BUILD_ROOT}/iphoneos/"
lipo -create "${PLATFORM_ROOT}"/build-iphonesimulator-{x86_64,arm64}/stage/libzano.a -output "${BUILD_ROOT}/iphonesimulator/libzano.a"
cp "${PLATFORM_ROOT}/build-iphoneos-arm64/stage/libzano-plain-wallet.a" "${BUILD_ROOT}/iphoneos/"
lipo -create "${PLATFORM_ROOT}"/build-iphonesimulator-{x86_64,arm64}/stage/libzano-plain-wallet.a -output "${BUILD_ROOT}/iphonesimulator/libzano-plain-wallet.a"

rm -rf "${FRAMEWORK_ROOT}"
xcodebuild -create-xcframework \
  -library "${BUILD_ROOT}/iphoneos/libzano.a" -headers "${PLATFORM_ROOT}/build-iphoneos-arm64/stage/include" \
  -library "${BUILD_ROOT}/iphonesimulator/libzano.a" -headers "${PLATFORM_ROOT}/build-iphonesimulator-arm64/stage/include" \
  -output "${FRAMEWORK_ROOT}"
if [ ! -d "${FRAMEWORK_ROOT}" ]; then
  echo Zano failed to create framework >&2
  exit 1
fi
cp "${PLATFORM_ROOT}/build-iphoneos-arm64/stage/VERSION" "${FRAMEWORK_ROOT}/VERSION"

rm -rf "${FRAMEWORK_PW_ROOT}"
xcodebuild -create-xcframework \
  -library "${BUILD_ROOT}/iphoneos/libzano-plain-wallet.a" -headers "${PLATFORM_ROOT}/build-iphoneos-arm64/stage/include-plain-wallet" \
  -library "${BUILD_ROOT}/iphonesimulator/libzano-plain-wallet.a" -headers "${PLATFORM_ROOT}/build-iphonesimulator-arm64/stage/include-plain-wallet" \
  -output "${FRAMEWORK_PW_ROOT}"
if [ ! -d "${FRAMEWORK_PW_ROOT}" ]; then
  echo Zano failed to create plain wallet framework >&2
  exit 1
fi
cp "${PLATFORM_ROOT}/build-iphoneos-arm64/stage/VERSION" "${FRAMEWORK_PW_ROOT}/VERSION"
