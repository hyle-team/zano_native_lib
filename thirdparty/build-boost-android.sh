#!/bin/bash

ROOT=$(realpath $(dirname $0)/..)
cd $(dirname $0)/boost-android

rm -rf ${ROOT}/_libs_android/boost
mkdir -p ${ROOT}/_libs_android/boost/include/../arm64-v8a/../armeabi-v7a/../x86/../x86_64

./build-android.sh \
  --boost=1.84.0 \
  --with-libraries=atomic,chrono,date_time,filesystem,program_options,regex,serialization,system,thread,timer \
  --target-version=26 \
  --layout=system \
  $ANDROID_NDK_ROOT

cp -r build/out/arm64-v8a/include/boost ${ROOT}/_libs_android/boost/include/
cp -r build/out/arm64-v8a/lib ${ROOT}/_libs_android/boost/arm64-v8a/
cp -r build/out/armeabi-v7a/lib ${ROOT}/_libs_android/boost/armeabi-v7a/
cp -r build/out/x86/lib ${ROOT}/_libs_android/boost/x86/
cp -r build/out/x86_64/lib ${ROOT}/_libs_android/boost/x86_64/
