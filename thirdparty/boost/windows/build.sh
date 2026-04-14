#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))
ROOT=$(realpath "${SCRIPT_ROOT}/../../..")
BOOST=$(realpath "${ROOT}/thirdparty/boost/windows")
cd "$BOOST"

BOOST_VERSION=${BOOST_VERSION:-1.76.0}
BOOST_TAR_HASH=${BOOST_TAR_HASH:-59cbd8a453c4cbc7e5bc9966101cbbb3c331858f11d341a72c80eae5a71fcc15}
BOOST_TAR_URL=${BOOST_TAR_URL:-https://archives.boost.io/release/${BOOST_VERSION}/binaries/boost_${BOOST_VERSION//./_}-msvc-14.2-64.exe}

${ROOT}/scripts/download-tar.sh Boost "${BOOST_TAR_URL}" ${BOOST_TAR_HASH} "${SCRIPT_ROOT}" "${BOOST}/prebuilds" || exit 1
