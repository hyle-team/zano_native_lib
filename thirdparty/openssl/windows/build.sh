#!/bin/bash

PROJECT_ROOT=$(realpath $(dirname $0)/../../..)
OPENSSL_DIR=$(realpath "${PROJECT_ROOT}/thirdparty/openssl/windows")

function BUILD() {
  local ARCH=$1; shift
  if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
    echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
    exit 1
  fi
  local BUILD_ROOT=${OPENSSL_DIR}/build-windows-${ARCH}

  echo "Preparing build folder: $BUILD_ROOT"
  "${PROJECT_ROOT}/thirdparty/openssl/download-openssl.sh" "$BUILD_ROOT" || exit 1
  cd "$BUILD_ROOT"


  local CONFIGURE_FLAGS=(${CONFIGURE_FLAGS})

  CONFIGURE_FLAGS+=("no-shared")
  CONFIGURE_FLAGS+=("no-tests")
  if [[ $ARCH == 'arm64' ]]; then
    CONFIGURE_FLAGS+=("VC-WIN64-ARM")
  elif [[ $ARCH == 'x86_64' ]]; then
    CONFIGURE_FLAGS+=("VC-WIN64A")
  fi

  # local CFLAGS=(${CFLAGS})
  # CFLAGS+=("-Wno-macro-redefined")
  # CFLAGS="${CFLAGS[*]}"
  # CONFIGURE_FLAGS+=("CFLAGS=${CFLAGS}")

  perl Configure ${CONFIGURE_FLAGS[*]} || exit 1
  nmake || exit 1

  rm -rf "${OPENSSL_DIR}"/{include,lib/${ARCH}}
  mkdir -p "${OPENSSL_DIR}"/include/../lib/${ARCH}
  cp "${BUILD_ROOT}"/*.lib "${OPENSSL_DIR}"/lib/${ARCH}/
  cp -r "${BUILD_ROOT}/include" "${OPENSSL_DIR}"/
}
BUILD x86_64
# BUILD arm64

source build-macosx-arm64/VERSION.dat
echo "${MAJOR}.${MINOR}.${PATCH}" > "${OPENSSL_DIR}/VERSION"
