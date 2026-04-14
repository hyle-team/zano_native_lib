#!/bin/bash

PROJECT_ROOT=$(realpath "$(dirname $0)/../../..")
BOOST_ROOT=$(realpath "${PROJECT_ROOT}/thirdparty/boost/android")
BOOST_VERSION=${BOOST_VERSION:-1.84.0}
ANDROID_TARGET=${ANDROID_TARGET:-26}

rm -rf ${BOOST_ROOT}/lib
rm -rf ${BOOST_ROOT}/include
mkdir -p ${BOOST_ROOT}/include/../lib/arm64-v8a/../armeabi-v7a/../x86/../x86_64

cd "${BOOST_ROOT}/Boost-for-Android"
./build-android.sh \
  --boost=${BOOST_VERSION} \
  --with-libraries=atomic,chrono,date_time,filesystem,program_options,regex,serialization,system,thread,timer \
  --target-version=${ANDROID_TARGET} \
  --layout=system \
  $ANDROID_NDK_ROOT
if [ ! -f build/out/arm64-v8a/lib/libboost_filesystem.a ]; then
  echo boost failed to build >&2
  exit 1
fi

cp -r build/out/arm64-v8a/include/boost ${BOOST_ROOT}/include/
cp -r build/out/arm64-v8a/lib/* ${BOOST_ROOT}/lib/arm64-v8a/
cp -r build/out/armeabi-v7a/lib/* ${BOOST_ROOT}/lib/armeabi-v7a/
cp -r build/out/x86/lib/* ${BOOST_ROOT}/lib/x86/
cp -r build/out/x86_64/lib/* ${BOOST_ROOT}/lib/x86_64/

echo "${BOOST_VERSION}" > "${BOOST_ROOT}/VERSION"
