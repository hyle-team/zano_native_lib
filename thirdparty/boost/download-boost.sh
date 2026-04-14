#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
ROOT=$(realpath "${SCRIPT_ROOT}/../../")

BOOST_VERSION=${BOOST_VERSION:-1.76.0}
BOOST_TAR_HASH=${BOOST_TAR_HASH:-7bd7ddceec1a1dfdcbdb3e609b60d01739c38390a5f956385a12f3122049f0ca}
BOOST_TAR_URL=${BOOST_TAR_URL:-https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION//./_}.tar.gz}

${ROOT}/scripts/download-tar.sh Boost "${BOOST_TAR_URL}" ${BOOST_TAR_HASH} "${SCRIPT_ROOT}" "${1}" || exit 1
patch "${1}/tools/build/src/engine/build.sh" "${SCRIPT_ROOT}/no-warnings.patch"
