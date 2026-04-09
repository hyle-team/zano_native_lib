#!/bin/bash

ROOT=$(realpath "$(dirname $0)/../../..")
BOOST=$(realpath "${ROOT}/thirdparty/boost/android")
BOOST_VERSION=${BOOST_VERSION:-1.84.0}
ANDROID_TARGET=${ANDROID_TARGET:-26}

rm -rf ${BOOST}/lib
rm -rf ${BOOST}/include
mkdir -p ${BOOST}/include/../lib/arm64-v8a/../armeabi-v7a/../x86/../x86_64

cd "${BOOST}/Boost-for-Android"
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

cp -r build/out/arm64-v8a/include/boost ${BOOST}/include/
cp -r build/out/arm64-v8a/lib/* ${BOOST}/lib/arm64-v8a/
cp -r build/out/armeabi-v7a/lib/* ${BOOST}/lib/armeabi-v7a/
cp -r build/out/x86/lib/* ${BOOST}/lib/x86/
cp -r build/out/x86_64/lib/* ${BOOST}/lib/x86_64/

echo "${BOOST_VERSION}" > "${BOOST}/VERSION"
