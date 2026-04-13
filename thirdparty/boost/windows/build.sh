#!/bin/bash

ROOT=$(realpath $(dirname $0)/../../..)
BOOST=$(realpath "${ROOT}/thirdparty/boost/windows")
cd "$BOOST"

BOOST_VERSION=${BOOST_VERSION:-1.76.0}
BOOST_TAR_HASH=${BOOST_TAR_HASH:-59cbd8a453c4cbc7e5bc9966101cbbb3c331858f11d341a72c80eae5a71fcc15}
BOOST_TAR_NAME=boost_${BOOST_VERSION//./_}-msvc-14.2-64.exe
BOOST_TAR_URL=${BOOST_TAR_URL:-https://archives.boost.io/release/${BOOST_VERSION}/binaries/${BOOST_TAR_NAME}}

echo "Boost version: $BOOST_VERSION"
if [[ ! -e $BOOST_TAR_NAME ]]; then
  echo "Downloading Boost binaries: '$BOOST_TAR_URL'"
  curl -L $BOOST_TAR_URL -o $BOOST_TAR_NAME
fi
RESULT=$(sha256sum ${BOOST_TAR_NAME} | awk '{ print $1 }')
if [[ $RESULT != $BOOST_TAR_HASH ]]; then
  echo "ERROR: Boost tarball does not satisfy provided hash." >&2
  echo " Expected: $BOOST_TAR_HASH" >&2
  echo "   Actual: $RESULT" >&2
  echo "Deleting this tarball." >&2
  rm -rf $BOOST_TAR_NAME
  exit 1
fi

TARGET_DIR="${BOOST}/prebuilds"
echo "Preparing binaries folder: $TARGET_DIR"
rm -rf $TARGET_DIR
mkdir $TARGET_DIR
tar -xzf $BOOST_TAR_NAME -C $TARGET_DIR
content=($(ls $TARGET_DIR))
if [[ ${#content[@]} -eq 1 ]]; then
  mv ${TARGET_DIR}/${content[0]}/* ${TARGET_DIR}/
  rm -rf ${TARGET_DIR}/${content[0]}
fi
