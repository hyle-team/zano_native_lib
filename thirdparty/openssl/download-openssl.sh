#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
ROOT=$(realpath "${SCRIPT_ROOT}../../")

OPENSSL_VERSION=${OPENSSL_VERSION:-3.1.8}
OPENSSL_TAR_HASH=${OPENSSL_TAR_HASH:-d319da6aecde3aa6f426b44bbf997406d95275c5c59ab6f6ef53caaa079f456f}
OPENSSL_TAR_URL=${OPENSSL_TAR_URL:-https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz}

${ROOT}/scripts/download-sources.sh Boost "${OPENSSL_TAR_URL}" ${OPENSSL_TAR_HASH} "${SCRIPT_ROOT}" "${PWD}"
