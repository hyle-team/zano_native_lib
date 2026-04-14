#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
BOOST=$(realpath "${ROOT}/thirdparty/boost/linux")
cd "$BOOST"

rm -rf "${BOOST}/lib/"
rm -rf "${BOOST}/include/"
mkdir -p "${BOOST}/include/../lib/arm64/../x86_64"

${BOOST}/builder.sh arm64 || exit 1
if [ ! -f ${BOOST}/build-linux-arm64/stage/lib/libboost_atomic.a ]; then
  echo boost failed to build arm64 >&2
  exit 1
fi
cp -r ${BOOST}/build-linux-arm64/stage/lib/* "${BOOST}/lib/arm64/"

${BOOST}/builder.sh x86_64 || exit 1
if [ ! -f ${BOOST}/build-linux-x86_64/stage/lib/libboost_atomic.a ]; then
  echo boost failed to build x86_64 >&2
  exit 1
fi
cp -r ${BOOST}/build-linux-x86_64/stage/lib/* "${BOOST}/lib/x86_64/"

cp -r ${BOOST}/build-linux-arm64/boost "${BOOST}/include/"

${BOOST}/../get-boost-version.sh "${BOOST}/build-linux-arm64" > "${BOOST}/VERSION"
