#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/boost/ios")"
TARGET_ROOT="${PROJECT_ROOT}/_install_ios/lib/thirdparty"

cd "${PLATFORM_ROOT}/Apple-Boost-BuildScript"
rm -rf dist/boost.xcframework
if ! (cat boost.sh | grep 'archives.boost.io'); then patch -p1 < ../fixes.patch; fi
BOOST_VERSION=${BOOST_VERSION:-1.76.0}
MIN_VERSION=${MIN_IOS_VERSION:-$(xcrun --sdk $PLATFORM --show-sdk-version)}
MIN_IOS_VERSION=${MIN_VERSION} \
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

FRAMEWORK_ROOT=${TARGET_ROOT}/libboost.xcframework
rm -rf "${FRAMEWORK_ROOT}"
xcodebuild -create-xcframework \
  -library build/boost/${BOOST_VERSION}/ios/release/build/iphoneos/arm64/libboost.a \
  -headers build/boost/${BOOST_VERSION}/ios/release/prefix/include \
  -library build/boost/${BOOST_VERSION}/ios/release/build/iphonesimulator/libboost.a \
  -headers build/boost/${BOOST_VERSION}/ios/release/prefix/include \
  -output ${FRAMEWORK_ROOT}
echo "${BOOST_VERSION}" > "${FRAMEWORK_ROOT}/VERSION"

cd Apple-Boost-BuildScript
git restore boost.sh
