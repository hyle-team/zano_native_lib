#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
BOOST=$(realpath "${ROOT}/thirdparty/boost/macosx")
cd "$BOOST"

for ARCH in arm64 x86_64; do
  ${BOOST}/builder.sh ${ARCH} || exit 1
  if [ ! -f build-macosx-${ARCH}/libboost.a ]; then
    echo boost failed to build ${ARCH} >&2
    exit 1
  fi
done

rm -rf "${BOOST}/build-macosx"
mkdir -p "${BOOST}/build-macosx"
lipo -create ./build-macosx-arm64/libboost.a ./build-macosx-x86_64/libboost.a -output ./build-macosx/libboost.a

rm -rf "${BOOST}/build-include"
mkdir -p "${BOOST}/build-include"
cp -r ${BOOST}/build-macosx-arm64/boost "${BOOST}/build-include/"

BOOST_FRAMEWORK=${BOOST}/libboost.xcframework
rm -rf "${BOOST_FRAMEWORK}"
xcodebuild -create-xcframework -library "${BOOST}/build-macosx/libboost.a" -headers "${BOOST}/build-include" -output "${BOOST_FRAMEWORK}"
if [ ! -d ${BOOST_FRAMEWORK} ]; then
  echo boost failed to create framework >&2
  exit 1
fi

${BOOST}/../get-boost-version.sh "${BOOST}/build-macosx-arm64" > "${BOOST_FRAMEWORK}/VERSION"
