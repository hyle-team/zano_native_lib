#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
BOOST=$(realpath "${ROOT}/thirdparty/boost/ios")

cd $(dirname $0)/Apple-Boost-BuildScript
rm -rf dist/boost.xcframework
if ! (cat boost.sh | grep 'archives.boost.io'); then patch -p1 < ../fixes.patch; fi
BOOST_VERSION=${BOOST_VERSION:-1.76.0}
./boost.sh \
  -ios \
  --boost-version ${BOOST_VERSION} \
  --boost-libs "atomic chrono date_time filesystem program_options regex serialization system thread timer" \
  --no-thinning \
  --no-framework \
  --cxxflags "-Wno-enum-constexpr-conversion"
if [ ! -f build/boost/${BOOST_VERSION}/ios/release/build/iphoneos/arm64/libboost.a ]; then
  echo boost failed to build >&2
  exit 1
fi
lipo -create build/boost/${BOOST_VERSION}/ios/release/build/iphonesimulator/*/libboost.a -output build/boost/${BOOST_VERSION}/ios/release/build/iphonesimulator/libboost.a

BOOST_FRAMEWORK=${BOOST}/libboost.xcframework
rm -rf "${BOOST_FRAMEWORK}"
xcodebuild -create-xcframework \
  -library build/boost/${BOOST_VERSION}/ios/release/build/iphoneos/arm64/libboost.a \
  -headers build/boost/${BOOST_VERSION}/ios/release/prefix/include \
  -library build/boost/${BOOST_VERSION}/ios/release/build/iphonesimulator/libboost.a \
  -headers build/boost/${BOOST_VERSION}/ios/release/prefix/include \
  -output ${BOOST_FRAMEWORK}
echo "${BOOST_VERSION}" > "${BOOST_FRAMEWORK}/VERSION"

cd Apple-Boost-BuildScript
git restore boost.sh
