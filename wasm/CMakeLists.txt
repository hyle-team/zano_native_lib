cmake_minimum_required(VERSION 3.16)
project(zano_wallet_wasm)

# ============================================================================
# Detect Emscripten Build Environment
# ============================================================================

if(EMSCRIPTEN)
    message(STATUS "Building for WebAssembly with Emscripten")
    set(BUILD_WASM ON)
else()
    message(WARNING "This CMakeLists.txt is designed for Emscripten builds only")
    message(WARNING "Use: emcmake cmake ..")
    set(BUILD_WASM OFF)
endif()

# ============================================================================
# C++ Standard and Compiler Settings
# ============================================================================

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# ============================================================================
# Paths and Directories
# ============================================================================

set(ZANO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../Zano")
set(WASM_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src")

# Include directories from Zano project
include_directories(
    ${ZANO_ROOT}/src
    ${ZANO_ROOT}/contrib
    ${ZANO_ROOT}/contrib/epee/include
    ${ZANO_ROOT}/contrib/eos_portable_archive
    ${ZANO_ROOT}/contrib/jwt-cpp/include
    ${WASM_SRC_DIR}
)

# ============================================================================
# Build Definitions
# ============================================================================

add_definitions(
    -DMOBILE_WALLET_BUILD          # Use mobile wallet mode (no daemon)
    -DBUILD_WASM=1                 # WASM build flag
    -DDISABLE_TOR=1                # Disable TOR (not available in browser)
    -DDISABLE_P2P=1                # Disable P2P networking
    -DSTATICLIB                    # Static library mode
    -D_GNU_SOURCE                  # GNU extensions
    -DBOOST_NO_CXX98_FUNCTION_BASE # Boost compatibility
    -DUSE_OPEN_SSL_FOR_ECDSA       # Use OpenSSL for ECDSA
    -DENABLED_ENGINE_MDBX          # Enable MDBX database
)

# Disable GUI and unnecessary features
set(BUILD_GUI FALSE)
set(BUILD_TESTS FALSE)
set(DISABLE_TOR TRUE)

# ============================================================================
# Emscripten-Specific Configuration
# ============================================================================

if(EMSCRIPTEN)
    # Option 1: Use Emscripten OpenSSL port (default, easier)
    # Option 2: Use custom-built OpenSSL by setting OPENSSL_ROOT_DIR
    if(NOT DEFINED ENV{OPENSSL_ROOT_DIR})
        message(STATUS "Using Emscripten OpenSSL port via -sUSE_OPENSSL=1")
        set(USE_EMSCRIPTEN_OPENSSL_PORT ON)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -sUSE_OPENSSL=1")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -sUSE_OPENSSL=1")
    else()
        message(STATUS "Using custom OpenSSL from: $ENV{OPENSSL_ROOT_DIR}")
        set(USE_EMSCRIPTEN_OPENSSL_PORT OFF)
        set(OPENSSL_ROOT_DIR $ENV{OPENSSL_ROOT_DIR})
    endif()

    # Use Emscripten Boost port (or expect pre-built Boost)
    # Note: Boost for WASM typically needs to be built separately
    # Set BOOST_ROOT environment variable if using custom Boost

    # Additional compiler flags for WASM
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fpermissive -ftemplate-depth-1024")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated-declarations")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unused-parameter")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-unused-variable")
endif()

# ============================================================================
# Find Dependencies
# ============================================================================

# OpenSSL Configuration
if(EMSCRIPTEN)
    if(USE_EMSCRIPTEN_OPENSSL_PORT)
        # Using Emscripten's built-in OpenSSL port
        # No find_package needed - provided via -sUSE_OPENSSL=1
        message(STATUS "OpenSSL: Using Emscripten port")
    else()
        # Using custom-built OpenSSL for Emscripten
        set(OPENSSL_USE_STATIC_LIBS TRUE)
        find_package(OpenSSL REQUIRED)
        include_directories(${OPENSSL_INCLUDE_DIR})
        message(STATUS "OpenSSL: ${OPENSSL_VERSION} from ${OPENSSL_INCLUDE_DIR}")
    endif()
else()
    # Native build
    set(OPENSSL_USE_STATIC_LIBS TRUE)
    find_package(OpenSSL REQUIRED)
    include_directories(${OPENSSL_INCLUDE_DIR})
endif()

# Boost Configuration (following Zano's pattern)
set(ZANO_BOOST_MIN_VER 1.75)

# Always use local Boost installation rather than system-wide (unless ZANO_USE_SYSTEM_BOOST is defined)
if(NOT DEFINED ENV{ZANO_USE_SYSTEM_BOOST})
    set(Boost_NO_SYSTEM_PATHS ON)
endif()

if(EMSCRIPTEN)
    # For Emscripten, Boost must be pre-built for WASM
    # Set BOOST_ROOT environment variable to point to your Emscripten-built Boost
    # Example: export BOOST_ROOT=/path/to/boost_1_84_0_wasm
    message(STATUS "BOOST_ROOT hint: $ENV{BOOST_ROOT}")
    find_package(Boost ${ZANO_BOOST_MIN_VER} COMPONENTS
        system filesystem thread serialization program_options)

    if(Boost_FOUND)
        include_directories(${Boost_INCLUDE_DIRS})
        message(STATUS "Boost: ${Boost_VERSION} from ${Boost_INCLUDE_DIRS}")
    else()
        message(WARNING "Boost not found. Please build Boost for Emscripten and set BOOST_ROOT")
        message(WARNING "See: https://github.com/emscripten-core/emscripten/wiki/Building-Boost")
    endif()
else()
    # Native build
    find_package(Boost ${ZANO_BOOST_MIN_VER} REQUIRED COMPONENTS
        system filesystem thread serialization program_options)
    include_directories(${Boost_INCLUDE_DIRS})
    message(STATUS "Boost: ${Boost_VERSION}")
endif()

# ============================================================================
# Source Files from Zano Project
# ============================================================================

# NOTE: This is a simplified list. A full build would need all wallet sources.
# For initial prototype, we'll link against required components.

set(WALLET_SOURCES
    ${ZANO_ROOT}/src/wallet/plain_wallet_api.cpp
    # Add more wallet sources as needed:
    # ${ZANO_ROOT}/src/wallet/wallet2.cpp
    # ${ZANO_ROOT}/src/wallet/wallets_manager.cpp
    # etc.
)

set(CRYPTO_SOURCES
    # Add crypto sources as needed:
    # ${ZANO_ROOT}/src/crypto/crypto.cpp
    # ${ZANO_ROOT}/src/crypto/clsag.cpp
    # etc.
)

set(COMMON_SOURCES
    # Add common sources as needed:
    # ${ZANO_ROOT}/src/common/*.cpp
)

# WASM wrapper sources
set(WASM_WRAPPER_SOURCES
    ${WASM_SRC_DIR}/c_api.cpp
    ${WASM_SRC_DIR}/transport_js.cpp
)

# ============================================================================
# Build Target
# ============================================================================

if(EMSCRIPTEN)
    # Create WASM executable (generates .js + .wasm)
    add_executable(zano_wallet
        ${WASM_WRAPPER_SOURCES}
        # Note: For full build, uncomment source lists above
        # ${WALLET_SOURCES}
        # ${CRYPTO_SOURCES}
        # ${COMMON_SOURCES}
    )

    # Link dependencies
    if(USE_EMSCRIPTEN_OPENSSL_PORT)
        # OpenSSL linked via -sUSE_OPENSSL=1 flag
        message(STATUS "Linking: Emscripten OpenSSL port (via flags)")
    else()
        # Link custom OpenSSL
        target_link_libraries(zano_wallet OpenSSL::SSL OpenSSL::Crypto)
        message(STATUS "Linking: Custom OpenSSL")
    endif()

    if(Boost_FOUND)
        target_link_libraries(zano_wallet ${Boost_LIBRARIES})
        message(STATUS "Linking: Boost libraries")
    endif()

    # ========================================================================
    # Emscripten Link Flags
    # ========================================================================

    set(EM_LINK_FLAGS
        -O3                                    # Optimize for production
        -sMODULARIZE=1                        # ES6 module export
        -sEXPORT_ES6=1                        # Use export default
        -sEXPORT_NAME=createZanoWalletModule  # Module factory name
        -sENVIRONMENT=web,worker              # Target environments
        -sALLOW_MEMORY_GROWTH=1               # Dynamic memory allocation
        -sWASM_BIGINT=1                       # BigInt support for int64
        -sASYNCIFY=1                          # Enable async/await in C++
        -sASYNCIFY_STACK_SIZE=65536          # Stack size for async operations
        -sSTACK_SIZE=5MB                      # Main stack size
        -sINITIAL_MEMORY=64MB                 # Initial WASM memory
        -sTOTAL_STACK=5MB                     # Total stack allocation
        -sEXPORTED_RUNTIME_METHODS=['ccall','cwrap','FS']  # Export Emscripten runtime
        -sFILESYSTEM=1                        # Enable file system
        -lnodefs.js                           # Node.js file system (for testing)
        -lidbfs.js                            # IndexedDB file system
        -sUSE_OPENSSL=1                       # Link OpenSSL
        -sNO_DISABLE_EXCEPTION_CATCHING       # Allow C++ exceptions
        -sASSERTIONS=1                        # Enable runtime assertions (debug)
    )

    # Exported C API functions
    set(EXPORTED_FUNCTIONS
        '_pw_init'
        '_pw_init_ip_port'
        '_pw_reset'
        '_pw_set_log_level'
        '_pw_get_version'
        '_pw_get_wallet_files'
        '_pw_delete_wallet'
        '_pw_is_wallet_exist'
        '_pw_get_export_private_info'
        '_pw_get_appconfig'
        '_pw_set_appconfig'
        '_pw_generate_random_key'
        '_pw_get_logs_buffer'
        '_pw_truncate_log'
        '_pw_get_connectivity_status'
        '_pw_get_address_info'
        '_pw_generate'
        '_pw_restore'
        '_pw_open'
        '_pw_close_wallet'
        '_pw_get_opened_wallets'
        '_pw_get_wallet_status'
        '_pw_get_wallet_info'
        '_pw_reset_wallet_password'
        '_pw_invoke'
        '_pw_get_current_tx_fee'
        '_pw_async_call'
        '_pw_try_pull_result'
        '_pw_sync_call'
        '_pw_free'
    )

    # Convert function list to JSON array format for Emscripten
    list(JOIN EXPORTED_FUNCTIONS "','" EXPORTED_FUNCTIONS_STR)
    set(EM_LINK_FLAGS ${EM_LINK_FLAGS} "-sEXPORTED_FUNCTIONS=['${EXPORTED_FUNCTIONS_STR}']")

    # Apply link flags
    target_link_options(zano_wallet PRIVATE ${EM_LINK_FLAGS})

    # Set output naming
    set_target_properties(zano_wallet PROPERTIES
        OUTPUT_NAME "zano_wallet"
        SUFFIX ".js"
    )

    # ========================================================================
    # Installation
    # ========================================================================

    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/zano_wallet.js
        ${CMAKE_CURRENT_BINARY_DIR}/zano_wallet.wasm
        DESTINATION ${CMAKE_INSTALL_PREFIX}
    )

    message(STATUS "WASM build configured successfully")
    message(STATUS "Output: zano_wallet.js + zano_wallet.wasm")
    message(STATUS "Build with: emmake make")

else()
    message(FATAL_ERROR "This build requires Emscripten. Use: emcmake cmake ..")
endif()

# ============================================================================
# Custom Targets and Commands
# ============================================================================

# Custom target to verify Emscripten setup
add_custom_target(check_emscripten
    COMMAND ${CMAKE_COMMAND} -E echo "Checking Emscripten environment..."
    COMMAND emcc --version
    COMMENT "Verifying Emscripten installation"
)

# Custom target to clean WASM artifacts
add_custom_target(clean_wasm
    COMMAND ${CMAKE_COMMAND} -E remove -f zano_wallet.js zano_wallet.wasm
    COMMENT "Cleaning WASM build artifacts"
)
