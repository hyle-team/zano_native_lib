#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/iconv/macosx")"
TARGET_ROOT="${PROJECT_ROOT}/_install_macosx/"
FRAMEWORK_ROOT="${TARGET_ROOT}/libiconv.xcframework"

[[ ! -d "${PLATFORM_ROOT}/build-x86_64" ]] && "${PLATFORM_ROOT}/build.sh" x86_64
[[ ! -d "${PLATFORM_ROOT}/build-arm64" ]] && "${PLATFORM_ROOT}/build.sh" arm64

BUILD_ROOT="${PLATFORM_ROOT}/build-framework"
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}"
lipo -create "${PLATFORM_ROOT}"/build-{x86_64,arm64}/stage/lib/libiconv.a -output "${BUILD_ROOT}/libiconv.a"

rm -rf "${FRAMEWORK_ROOT}"
xcodebuild -create-xcframework -library "${BUILD_ROOT}/libiconv.a" -headers "${PLATFORM_ROOT}/build-x86_64/stage/include" -output "${FRAMEWORK_ROOT}"
if [ ! -d "${FRAMEWORK_ROOT}" ]; then
  echo iconv failed to create framework >&2
  exit 1
fi
cp "${PLATFORM_ROOT}/build-x86_64/stage/VERSION" "${FRAMEWORK_ROOT}/VERSION"
