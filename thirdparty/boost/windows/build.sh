#!/bin/bash

PROJECT_ROOT=$(realpath $(dirname $0)/../../..)
BOOST_DIR=$(realpath "${PROJECT_ROOT}/thirdparty/boost/windows")

function BUILD() {
  local ARCH=$1; shift
  if ! [[ $ARCH == "arm64" || $ARCH == "x86_64" ]]; then
    echo "ERROR: Unsupported architecture: '${ARCH}'" >&2
    exit 1
  fi
  local BUILD_ROOT=${BOOST_DIR}/build-windows-${ARCH}

  echo "Preparing build folder: $BUILD_ROOT"
  "${PROJECT_ROOT}/thirdparty/boost/download-boost.sh" "$BUILD_ROOT" || exit 1
  cd "$BUILD_ROOT"

  cmd.exe /c "bootstrap.bat --with-libraries=atomic,chrono,date_time,filesystem,regex,serialization,system,thread,timer,program_options,locale,log"

  # local CXX_FLAGS=(${CXX_FLAGS})
  # CXX_FLAGS+=("-Wno-enum-constexpr-conversion")

  local B2_FLAGS=(${B2_FLAGS})
  B2_FLAGS+=("link=static")
  B2_FLAGS+=("toolset=msvc")
  B2_FLAGS+=("variant=release")
  B2_FLAGS+=("threading=multi")
  B2_FLAGS+=("runtime-link=shared")
  B2_FLAGS+=("address-model=64")
  if [[ $ARCH == 'arm64' ]]; then
    B2_FLAGS+=("architecture=arm")
  else
    B2_FLAGS+=("architecture=x86")
  fi
  # CXX_FLAGS="${CXX_FLAGS[*]}"
  # [ -n "$CXX_FLAGS" ] && B2_FLAGS+=("cxxflags=${CXX_FLAGS}")

  cmd.exe /c "b2.exe ${B2_FLAGS[*]} --with-atomic --with-chrono --with-date_time --with-filesystem --with-regex --with-serialization --with-system --with-thread --with-timer --with-program_options --with-locale --with-log stage"

  rm -rf "${BOOST_DIR}"/{include,lib/${ARCH}}
  mkdir -p "${BOOST_DIR}"/include/../lib/${ARCH}
  cp "${BUILD_ROOT}/stage/lib/*.lib" "${BOOST_DIR}"/lib/${ARCH}/
  cp "${BUILD_ROOT}/boost" "${BOOST_DIR}"/include/
}
BUILD x86_64
# BUILD arm64

${PROJECT_ROOT}/thirdparty/boost/get-boost-version.sh "${BOOST}/build-windows-x86_64" > "${BOOST_DIR}/VERSION"
