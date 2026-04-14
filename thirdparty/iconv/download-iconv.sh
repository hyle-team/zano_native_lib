#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
ROOT=$(realpath "${SCRIPT_ROOT}/../../")

ICONV_VERSION=${ICONV_VERSION:-1.18}
ICONV_TAR_HASH=${ICONV_TAR_HASH:-3b08f5f4f9b4eb82f151a7040bfd6fe6c6fb922efe4b1659c66ea933276965e8}
ICONV_TAR_URL=${ICONV_TAR_URL:-https://ftpmirror.gnu.org/libiconv/libiconv-${ICONV_VERSION}.tar.gz}

${ROOT}/scripts/download-tar.sh iconv "${ICONV_TAR_URL}" ${ICONV_TAR_HASH} "${SCRIPT_ROOT}" "${1}" || exit 1
