#!/bin/bash

REPO_ROOT=$(realpath $(dirname $0)/../../..)
ROOT=$(realpath "${REPO_ROOT}/thirdparty/iconv/macosx")
cd "$ROOT"

for ARCH in arm64 x86_64; do
  ${ROOT}/builder.sh ${ARCH} || exit 1
  if [ ! -f build-macosx-${ARCH}/stage/lib/libiconv.a ]; then
    echo iconv failed to build ${ARCH} >&2
    exit 1
  fi
done

rm -rf "${ROOT}/build-macosx"
mkdir -p "${ROOT}/build-macosx"
lipo -create ./build-macosx-arm64/stage/lib/libiconv.a ./build-macosx-x86_64/stage/lib/libiconv.a -output ./build-macosx/libiconv.a

rm -rf "${ROOT}/build-include"
mkdir -p "${ROOT}/build-include"
cp -r ${ROOT}/build-macosx-arm64/stage/include/*.h "${ROOT}/build-include/"

FRAMEWORK=${ROOT}/libiconv.xcframework
rm -rf "${FRAMEWORK}"
xcodebuild -create-xcframework -library "${ROOT}/build-macosx/libiconv.a" -headers "${ROOT}/build-include" -output "${FRAMEWORK}"
if [ ! -d ${FRAMEWORK} ]; then
  echo iconv failed to create framework >&2
  exit 1
fi

for ARCH in arm64 x86_64; do
  cp "${ROOT}/build-macosx-${ARCH}/stage/bin/iconv" "${FRAMEWORK}/iconv-${ARCH}"
done
${ROOT}/../get-iconv-version.sh "${ROOT}/build-macosx-arm64" > "${FRAMEWORK}/VERSION"
