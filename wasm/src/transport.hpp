// Copyright (c) 2014-2025 Zano Project
// Transport Abstraction Layer for WASM
// Provides HTTP client abstraction for daemon communication
// Distributed under the MIT/X11 software license

#pragma once
#include <string>

namespace transport {

/**
 * Execute HTTP POST with JSON payload (for Daemon JSON-RPC)
 *
 * In WASM builds: Uses JavaScript fetch() API via Emscripten bridge
 * In native builds: Uses Boost.Asio HTTP client (original implementation)
 *
 * @param url Full URL (e.g., "https://daemon.example.com:11211/json_rpc")
 * @param json_body JSON request body
 * @return JSON response string
 * @throws std::runtime_error on network or HTTP errors
 */
std::string rpc_json(const std::string& url, const std::string& json_body);

/**
 * Execute HTTP POST with binary payload
 * Used for binary RPC commands (if needed)
 *
 * @param url Full URL
 * @param binary_body Binary request data
 * @return Binary response data
 * @throws std::runtime_error on network or HTTP errors
 */
std::string rpc_binary(const std::string& url, const std::string& binary_body);

/**
 * Check if transport layer is initialized and ready
 * @return true if ready, false otherwise
 */
bool is_ready();

/**
 * Get last error message (if any)
 * @return Error description or empty string
 */
std::string get_last_error();

} // namespace transport
