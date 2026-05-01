#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/openssl/macosx")"
TARGET_ROOT="${PROJECT_ROOT}/_install_macosx/"
FRAMEWORK_ROOT="${TARGET_ROOT}/libopenssl.xcframework"

[[ ! -d "${PLATFORM_ROOT}/build-x86_64" ]] && "${PLATFORM_ROOT}/build.sh" x86_64
[[ ! -d "${PLATFORM_ROOT}/build-arm64" ]] && "${PLATFORM_ROOT}/build.sh" arm64

BUILD_ROOT="${PLATFORM_ROOT}/build-framework"
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"
lipo -create "${PLATFORM_ROOT}"/build-{x86_64,arm64}/libopenssl.a -output "${BUILD_ROOT}/libopenssl.a"

rm -rf "${FRAMEWORK_ROOT}"
xcodebuild -create-xcframework -library "${BUILD_ROOT}/libopenssl.a" -headers "${PLATFORM_ROOT}/build-x86_64/include" -output "${FRAMEWORK_ROOT}"
if [ ! -d "${FRAMEWORK_ROOT}" ]; then
  echo OpenSSL failed to create framework >&2
  exit 1
fi
cp "${PLATFORM_ROOT}/build-x86_64/VERSION" "${FRAMEWORK_ROOT}/VERSION"
