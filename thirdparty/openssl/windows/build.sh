#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
ROOT=$(realpath "${SCRIPT_ROOT}/../../..")
OPENSSL=$(realpath "${ROOT}/thirdparty/openssl/windows")
cd "$OPENSSL"

OPENSSL_VERSION=${OPENSSL_VERSION:-3.6.2}
OPENSSL_TAR_HASH=${OPENSSL_TAR_HASH:-c395482a1af33b2cdd4b801b227c864ed049e0f6aff79413d31b4fa916a67b1a}
OPENSSL_TAR_URL=${OPENSSL_TAR_URL:-https://slproweb.com/download/Win64OpenSSL-${OPENSSL_VERSION//./_}.exe}
# OPENSSL_TAR_URL=${OPENSSL_TAR_URL:-https://slproweb.com/download/Win64ARMOpenSSL-${OPENSSL_VERSION//./_}.exe}

${ROOT}/scripts/download-tar.sh OpenSSL "${OPENSSL_TAR_URL}" ${OPENSSL_TAR_HASH} "${SCRIPT_ROOT}" "${OPENSSL}/prebuilds" || exit 1
