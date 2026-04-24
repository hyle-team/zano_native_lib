#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/boost/android")"
TARGET_ROOT="${PROJECT_ROOT}/_libs_android/boost"
BOOST_VERSION=${BOOST_VERSION:-1.84.0}
ANDROID_TARGET=${ANDROID_TARGET:-26}

cd "${PLATFORM_ROOT}/Boost-for-Android"
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

rm -rf "${TARGET_ROOT}/include"
mkdir -p "${TARGET_ROOT}/include/"
cp -r build/out/arm64-v8a/include/boost "${TARGET_ROOT}/include/"
for ARCH in arm64-v8a armeabi-v7a x86 x86_64; do
  rm -rf "${TARGET_ROOT}/${ARCH}"
  mkdir -p "${TARGET_ROOT}/${ARCH}/lib/"
  cp -r build/out/${ARCH}/lib/* "${TARGET_ROOT}/${ARCH}/lib/"
  echo "${BOOST_VERSION}" > "${TARGET_ROOT}/${ARCH}/VERSION"
done
