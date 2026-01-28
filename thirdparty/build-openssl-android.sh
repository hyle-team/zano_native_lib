#!/bin/bash

ROOT=$(realpath $(dirname $0)/..)
cd $(dirname $0)/openssl-android
for arch in arm64-v8a armeabi-v7a x86 x86_64; do
  ANDROID_TARGET=26 ./build.sh $arch $ANDROID_NDK_ROOT
  cp build-$arch/{libssl,libcrypto}.a $ROOT/_libs_android/openssl/$arch/lib/
done
cp -r build-arm64-v8a/include/* $ROOT/_libs_android/openssl/include/
