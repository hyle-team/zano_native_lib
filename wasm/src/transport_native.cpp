// Copyright (c) 2014-2025 Zano Project
// Transport Layer Fallback for Native Builds (non-WASM)
// Uses existing Boost.Asio HTTP client
// Distributed under the MIT/X11 software license

#ifndef __EMSCRIPTEN__

#include "transport.hpp"
#include <stdexcept>

namespace {
    std::string g_last_error;
}

namespace transport {

// For native builds, this is a placeholder
// The actual plain_wallet code will use its native HTTP client directly
// This abstraction is only needed for WASM builds

std::string rpc_json(const std::string& url, const std::string& json_body) {
    g_last_error = "Native transport not implemented - use plain_wallet native HTTP client";
    throw std::runtime_error(g_last_error);
}

std::string rpc_binary(const std::string& url, const std::string& binary_body) {
    g_last_error = "Native transport not implemented - use plain_wallet native HTTP client";
    throw std::runtime_error(g_last_error);
}

bool is_ready() {
    return false;
}

std::string get_last_error() {
    return g_last_error;
}

} // namespace transport

#endif // !__EMSCRIPTEN__
