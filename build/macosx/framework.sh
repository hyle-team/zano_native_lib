#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/build/macosx")"
FRAMEWORK_ROOT="${PLATFORM_ROOT}/libzano.xcframework"
FRAMEWORK_PW_ROOT="${PLATFORM_ROOT}/libzano-plain-wallet.xcframework"

[[ ! -d "${PLATFORM_ROOT}/build-x86_64" ]] && "${PLATFORM_ROOT}/build.sh" x86_64
[[ ! -d "${PLATFORM_ROOT}/build-arm64" ]] && "${PLATFORM_ROOT}/build.sh" arm64

BUILD_ROOT="${PLATFORM_ROOT}/build-framework"
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"
lipo -create "${PLATFORM_ROOT}"/build-{x86_64,arm64}/stage/libzano.a -output "${BUILD_ROOT}/libzano.a"

rm -rf "${FRAMEWORK_ROOT}"
xcodebuild -create-xcframework -library "${BUILD_ROOT}/libzano.a" -headers "${PLATFORM_ROOT}/build-x86_64/stage/include" -output "${FRAMEWORK_ROOT}"
if [ ! -d "${FRAMEWORK_ROOT}" ]; then
  echo Zano failed to create framework >&2
  exit 1
fi
cp "${PLATFORM_ROOT}/build-x86_64/stage/VERSION" "${FRAMEWORK_ROOT}/VERSION"

libtool -static -o "${PLATFORM_ROOT}/build-x86_64/stage/libzano-plain-wallet.a" -arch_only x86_64 "${PLATFORM_ROOT}/build-x86_64/stage/libzano.a" "${PLATFORM_ROOT}/build-x86_64/dependencies.a"
libtool -static -o "${PLATFORM_ROOT}/build-arm64/stage/libzano-plain-wallet.a" -arch_only arm64 "${PLATFORM_ROOT}/build-arm64/stage/libzano.a" "${PLATFORM_ROOT}/build-arm64/dependencies.a"
lipo -create "${PLATFORM_ROOT}"/build-{x86_64,arm64}/stage/libzano-plain-wallet.a -output "${BUILD_ROOT}/libzano-plain-wallet.a"

rm -rf "${FRAMEWORK_PW_ROOT}"
xcodebuild -create-xcframework -library "${BUILD_ROOT}/libzano-plain-wallet.a" -headers "${PLATFORM_ROOT}/build-x86_64/stage/include-pw" -output "${FRAMEWORK_PW_ROOT}"
if [ ! -d "${FRAMEWORK_PW_ROOT}" ]; then
  echo Zano failed to create plain wallet framework >&2
  exit 1
fi
cp "${PLATFORM_ROOT}/build-x86_64/stage/VERSION" "${FRAMEWORK_PW_ROOT}/VERSION"
