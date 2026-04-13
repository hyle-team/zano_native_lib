#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
BOOST=$(realpath "${ROOT}/thirdparty/boost/macosx")
cd "$BOOST"

${BOOST}/builder.sh arm64
if [ ! -f build-macosx-arm64/libboost.a ]; then
  echo boost failed to build arm64 >&2
  exit 1
fi

${BOOST}/builder.sh x86_64
if [ ! -f build-macosx-x86_64/libboost.a ]; then
  echo boost failed to build x86_64 >&2
  exit 1
fi

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

cd ${BOOST}/build-macosx-arm64
${BOOST}/../get-boost-version.sh > "${BOOST_FRAMEWORK}/VERSION"
