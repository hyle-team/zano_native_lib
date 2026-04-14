#!/bin/bash

REPO_ROOT=$(realpath $(dirname $0)/../../..)
ROOT=$(realpath "${REPO_ROOT}/thirdparty/iconv/linux")
cd "$ROOT"

rm -rf "${ROOT}/include"
rm -rf "${ROOT}/lib"
mkdir -p "${ROOT}/include/../lib/arm64/../x86_64/"

for ARCH in arm64 x86_64; do
  ${ROOT}/builder.sh ${ARCH} || exit 1
  if [ ! -f build-linux-${ARCH}/stage/lib/libiconv.a ]; then
    echo iconv failed to build ${ARCH} >&2
    exit 1
  fi
  cp "${ROOT}/build-linux-${ARCH}/stage/lib/libiconv.a" "${ROOT}/lib/${ARCH}/"
done

cp -r ${ROOT}/build-linux-arm64/stage/include/*.h "${ROOT}/include/"
${ROOT}/../get-iconv-version.sh "${ROOT}/build-linux-arm64" > "${ROOT}/VERSION"
