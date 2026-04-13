#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
BOOST=$(realpath "${ROOT}/thirdparty/boost/linux")
cd "$BOOST"

${BOOST}/builder.sh arm64
if [ ! -f build-linux-arm64/stage/lib/libboost_atomic.a ]; then
  echo boost failed to build arm64 >&2
  exit 1
fi
# copy build-linux-arm64/stage/lib/libboost_atomic.a

${BOOST}/builder.sh x86_64
if [ ! -f build-linux-x86_64/libboost.a ]; then
  echo boost failed to build x86_64 >&2
  exit 1
fi

rm -rf "${BOOST}/build-include"
mkdir -p "${BOOST}/build-include"
cp -r ${BOOST}/build-linux-arm64/boost "${BOOST}/build-include/"

cd ${BOOST}/build-linux-arm64
${BOOST}/../get-boost-version.sh > "${BOOST_FRAMEWORK}/VERSION"
