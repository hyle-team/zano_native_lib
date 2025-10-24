#!/bin/bash
#
# Zano WASM Wallet Library Build Script
# Copyright (c) 2014-2025 Zano Project
#
# This script builds the Zano wallet library for WebAssembly using Emscripten
#

set -euo pipefail

# Default dependency locations (override by exporting before running this script)
: "${EMSDK:=$HOME/emsdk}"
: "${BOOST_ROOT:=$HOME/boost_emscripten}"
: "${OPENSSL_ROOT_DIR:=$HOME/openssl}"

# Ensure Emscripten environment is loaded (ignore if already sourced)
if [ -d "${EMSDK}" ] && [ -f "${EMSDK}/emsdk_env.sh" ]; then
  # shellcheck disable=SC1090
  source "${EMSDK}/emsdk_env.sh" >/dev/null 2>&1 || true
fi

# Export for downstream tools
export EMSDK
export BOOST_ROOT
export OPENSSL_ROOT_DIR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/_build"
INSTALL_DIR="${SCRIPT_DIR}/_install"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Zano WASM Wallet Library Build${NC}"
echo -e "${GREEN}========================================${NC}"

# ============================================================================
# Step 1: Verify Emscripten
# ============================================================================

echo -e "\n${YELLOW}[1/5] Checking Emscripten environment...${NC}"

if [ -z "${EMSDK:-}" ]; then
    echo -e "${RED}ERROR: EMSDK environment variable not set${NC}"
    echo -e "${YELLOW}Please install and activate Emscripten SDK:${NC}"
    echo -e "  git clone https://github.com/emscripten-core/emsdk.git"
    echo -e "  cd emsdk"
    echo -e "  ./emsdk install latest"
    echo -e "  ./emsdk activate latest"
    echo -e "  source ./emsdk_env.sh"
    exit 1
fi

if ! command -v emcc &> /dev/null; then
    echo -e "${RED}ERROR: emcc not found in PATH${NC}"
    echo -e "${YELLOW}Please run: source \$EMSDK/emsdk_env.sh${NC}"
    exit 1
fi

EMCC_VERSION=$(emcc --version | head -n 1)
echo -e "${GREEN}✓ Emscripten found: ${EMCC_VERSION}${NC}"

# ============================================================================
# Step 2: Check CMake
# ============================================================================

echo -e "\n${YELLOW}[2/5] Checking CMake...${NC}"

if ! command -v cmake &> /dev/null; then
    echo -e "${RED}ERROR: CMake not found${NC}"
    echo -e "${YELLOW}Please install CMake 3.16 or later${NC}"
    exit 1
fi

CMAKE_VERSION=$(cmake --version | head -n 1)
echo -e "${GREEN}✓ CMake found: ${CMAKE_VERSION}${NC}"

# ============================================================================
# Step 3: Clean previous build
# ============================================================================

echo -e "\n${YELLOW}[3/5] Cleaning previous build...${NC}"

if [ -d "${BUILD_DIR}" ]; then
    echo -e "Removing ${BUILD_DIR}"
    rm -rf "${BUILD_DIR}"
fi

if [ -d "${INSTALL_DIR}" ]; then
    echo -e "Removing ${INSTALL_DIR}"
    rm -rf "${INSTALL_DIR}"
fi

mkdir -p "${BUILD_DIR}"
mkdir -p "${INSTALL_DIR}"

echo -e "${GREEN}✓ Build directories created${NC}"

# ============================================================================
# Step 4: Configure with CMake
# ============================================================================

echo -e "\n${YELLOW}[4/5] Configuring with CMake...${NC}"

cd "${BUILD_DIR}"

# Run emcmake to configure
emcmake cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DBUILD_TESTS=OFF \
  -DDISABLE_TOR=ON \
  -DBUILD_GUI=OFF \
  -DBoost_ROOT="${BOOST_ROOT}" \
  -DBoost_NO_SYSTEM_PATHS=ON \
  -DBoost_INCLUDE_DIR="${BOOST_ROOT}/include" \
  -DBoost_LIBRARY_DIR="${BOOST_ROOT}/lib" \
  -DBoost_LIBRARY_DIRS="${BOOST_ROOT}/lib" \
  -DBoost_USE_STATIC_LIBS=ON \
  -DCMAKE_TOOLCHAIN_FILE="${EMSDK}/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake" \
  -DCMAKE_CROSSCOMPILING_EMULATOR="${EMSDK}/node/22.16.0_64bit/bin/node" \
  -DOPENSSL_ROOT_DIR="${OPENSSL_ROOT_DIR}" \
  -DOPENSSL_INCLUDE_DIR="${OPENSSL_ROOT_DIR}/include" \
  -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_ROOT_DIR}/lib/libcrypto.a" \
  -DOPENSSL_SSL_LIBRARY="${OPENSSL_ROOT_DIR}/lib/libssl.a"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ CMake configuration failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ CMake configuration successful${NC}"

# ============================================================================
# Step 5: Build with emmake
# ============================================================================

echo -e "\n${YELLOW}[5/5] Building WASM module...${NC}"

# Determine number of parallel jobs
if command -v nproc &> /dev/null; then
    JOBS=$(nproc)
elif command -v sysctl &> /dev/null; then
    JOBS=$(sysctl -n hw.ncpu)
else
    JOBS=4
fi

echo -e "Building with ${JOBS} parallel jobs..."

emmake make -j${JOBS}

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"

# ============================================================================
# Step 6: Copy outputs to install directory
# ============================================================================

echo -e "\n${YELLOW}Installing outputs...${NC}"

if [ -f "zano_wallet.js" ]; then
    cp zano_wallet.js "${INSTALL_DIR}/"
    echo -e "${GREEN}✓ Copied zano_wallet.js${NC}"
else
    echo -e "${YELLOW}⚠ zano_wallet.js not found${NC}"
fi

if [ -f "zano_wallet.wasm" ]; then
    cp zano_wallet.wasm "${INSTALL_DIR}/"
    WASM_SIZE=$(stat -f%z "${INSTALL_DIR}/zano_wallet.wasm" 2>/dev/null || stat -c%s "${INSTALL_DIR}/zano_wallet.wasm" 2>/dev/null || echo "unknown")
    if [ "$WASM_SIZE" != "unknown" ]; then
        WASM_SIZE_MB=$((WASM_SIZE / 1024 / 1024))
        echo -e "${GREEN}✓ Copied zano_wallet.wasm (${WASM_SIZE_MB} MB)${NC}"

        if [ $WASM_SIZE_MB -gt 50 ]; then
            echo -e "${YELLOW}⚠ Warning: WASM file is quite large (${WASM_SIZE_MB} MB)${NC}"
            echo -e "${YELLOW}  Consider optimization flags or lazy loading${NC}"
        fi
    else
        echo -e "${GREEN}✓ Copied zano_wallet.wasm${NC}"
    fi
else
    echo -e "${YELLOW}⚠ zano_wallet.wasm not found${NC}"
fi

# ============================================================================
# Build Summary
# ============================================================================

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e ""
echo -e "Output files:"
echo -e "  ${INSTALL_DIR}/zano_wallet.js"
echo -e "  ${INSTALL_DIR}/zano_wallet.wasm"
echo -e ""
echo -e "Next steps:"
echo -e "  1. Create JavaScript/TypeScript wrapper"
echo -e "  2. Test in browser environment"
echo -e "  3. Integrate with your application"
echo -e ""
echo -e "To rebuild:"
echo -e "  cd ${SCRIPT_DIR}"
echo -e "  ./build-wasm.sh"
echo -e ""
