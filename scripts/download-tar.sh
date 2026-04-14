#!/bin/bash

SCRIPT_ROOT=$(realpath $(dirname $0))

LIB_NAME=${1}
LIB_TAR_URL=${2}
LIB_TAR_HASH=${3}
LIB_TAR_NAME=$(basename "${2}")
STORE_DIR=${4}
TARGET_DIR=${5}

echo "${LIB_NAME} version: $LIB_TAR_NAME"
if [[ ! -e "${STORE_DIR}/${LIB_TAR_NAME}" ]]; then
  echo "Downloading ${LIB_NAME} tarball: '$LIB_TAR_URL'"
  curl -L $LIB_TAR_URL -o "${STORE_DIR}/${LIB_TAR_NAME}"
fi
HASH_RESULT=$(sha256sum "${STORE_DIR}/${LIB_TAR_NAME}" | awk '{ print $1 }')
if [[ $HASH_RESULT != $LIB_TAR_HASH ]]; then
  echo "ERROR: ${LIB_NAME} tarball does not satisfy provided hash." >&2
  echo " Expected: $LIB_TAR_HASH" >&2
  echo "   Actual: $HASH_RESULT" >&2
  echo "Deleting this tarball." >&2
  rm -rf "${STORE_DIR}/${LIB_TAR_NAME}"
  exit 1
fi

rm -rf $TARGET_DIR
mkdir -p $TARGET_DIR
tar -xzf "${STORE_DIR}/${LIB_TAR_NAME}" -C $TARGET_DIR
content=($(ls $TARGET_DIR))
if [[ ${#content[@]} -eq 1 ]]; then
  mv ${TARGET_DIR}/${content[0]}/* ${TARGET_DIR}/
  rm -rf ${TARGET_DIR}/${content[0]}
fi
