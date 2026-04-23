#!/bin/bash

PROJECT_ROOT="$(realpath "$(dirname "$0")/../../..")"
PLATFORM_ROOT="$(realpath "${PROJECT_ROOT}/thirdparty/boost/android")"
BOOST_VERSION=${BOOST_VERSION:-1.84.0}
ANDROID_TARGET=${ANDROID_TARGET:-26}

for ARCH in arm64-v8a armeabi-v7a x86 x86_64; do
  rm -rf ${PLATFORM_ROOT}/${ARCH}
  mkdir -p ${PLATFORM_ROOT}/${ARCH}/lib/../include/
done

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

for ARCH in arm64-v8a armeabi-v7a x86 x86_64; do
  cp -r build/out/${ARCH}/include/boost ${PLATFORM_ROOT}/${ARCH}/include/
  cp -r build/out/${ARCH}/lib/* ${PLATFORM_ROOT}/${ARCH}/lib/
  echo "${BOOST_VERSION}" > "${PLATFORM_ROOT}/${ARCH}/VERSION"

  # Backport to old folders
  rm -rf "${PROJECT_ROOT}"/_libs_android/boost/${ARCH}/lib
  cp -r "${PLATFORM_ROOT}/${ARCH}/lib" "${PROJECT_ROOT}/_libs_android/boost/${ARCH}/"
done

# Backport to old folders
rm -rf "${PROJECT_ROOT}"/_libs_android/boost/include
cp -r "${PLATFORM_ROOT}/arm64-v8a/include" "${PROJECT_ROOT}/_libs_android/boost/"
