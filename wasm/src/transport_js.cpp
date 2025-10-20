// Copyright (c) 2014-2025 Zano Project
// Transport Layer Implementation for WASM (using Emscripten + JavaScript fetch)
// Distributed under the MIT/X11 software license

#ifdef __EMSCRIPTEN__

#include "transport.hpp"
#include <emscripten.h>
#include <stdexcept>
#include <cstdlib>
#include <cstring>

namespace {
    std::string g_last_error;
}

// Emscripten JavaScript bridge for HTTP fetch
// Note: Requires -sASYNCIFY=1 compile flag to handle async JavaScript from C++
EM_JS(char*, _fetch_http, (const char* url, const char* body, const char* content_type), {
    const urlStr = UTF8ToString(url);
    const bodyStr = UTF8ToString(body);
    const contentTypeStr = UTF8ToString(content_type);

    return Asyncify.handleAsync(async () => {
        try {
            // Execute fetch request
            const response = await fetch(urlStr, {
                method: 'POST',
                headers: {
                    'Content-Type': contentTypeStr,
                    'Accept': 'application/json'
                },
                body: bodyStr,
                credentials: 'omit',  // Don't send cookies (security)
                cache: 'no-store',    // Don't cache daemon responses
                mode: 'cors'          // Allow CORS for daemon endpoints
            });

            // Check HTTP status
            if (!response.ok) {
                const errorText = await response.text();
                const errorMsg = `HTTP ${response.status}: ${response.statusText}\n${errorText}`;
                const len = lengthBytesUTF8(errorMsg) + 1;
                const ptr = _malloc(len);
                stringToUTF8(`ERROR:${errorMsg}`, ptr, len);
                return ptr;
            }

            // Read response body
            const text = await response.text();

            // Allocate memory for response string
            const len = lengthBytesUTF8(text) + 1;
            const ptr = _malloc(len);
            stringToUTF8(text, ptr, len);
            return ptr;

        } catch (err) {
            // Handle network errors, CORS failures, etc.
            const errorMsg = `Fetch failed: ${err.message || err.toString()}`;
            const len = lengthBytesUTF8(errorMsg) + 1;
            const ptr = _malloc(len);
            stringToUTF8(`ERROR:${errorMsg}`, ptr, len);
            return ptr;
        }
    });
});

namespace transport {

std::string rpc_json(const std::string& url, const std::string& json_body) {
    if (url.empty()) {
        g_last_error = "URL cannot be empty";
        throw std::runtime_error("Transport error: " + g_last_error);
    }

    // Call JavaScript fetch bridge
    char* result_ptr = _fetch_http(url.c_str(), json_body.c_str(), "application/json");

    if (result_ptr == nullptr) {
        g_last_error = "Fetch returned null pointer";
        throw std::runtime_error("Transport error: " + g_last_error);
    }

    std::string result(result_ptr);
    free(result_ptr);

    // Check if result starts with "ERROR:"
    if (result.find("ERROR:") == 0) {
        g_last_error = result.substr(6);  // Strip "ERROR:" prefix
        throw std::runtime_error("Transport error: " + g_last_error);
    }

    g_last_error.clear();
    return result;
}

std::string rpc_binary(const std::string& url, const std::string& binary_body) {
    if (url.empty()) {
        g_last_error = "URL cannot be empty";
        throw std::runtime_error("Transport error: " + g_last_error);
    }

    // Call JavaScript fetch bridge with binary content type
    char* result_ptr = _fetch_http(url.c_str(), binary_body.c_str(), "application/octet-stream");

    if (result_ptr == nullptr) {
        g_last_error = "Fetch returned null pointer";
        throw std::runtime_error("Transport error: " + g_last_error);
    }

    std::string result(result_ptr);
    free(result_ptr);

    // Check if result starts with "ERROR:"
    if (result.find("ERROR:") == 0) {
        g_last_error = result.substr(6);  // Strip "ERROR:" prefix
        throw std::runtime_error("Transport error: " + g_last_error);
    }

    g_last_error.clear();
    return result;
}

bool is_ready() {
    // In WASM, fetch API is always available in browser environment
    return true;
}

std::string get_last_error() {
    return g_last_error;
}

} // namespace transport

#endif // __EMSCRIPTEN__
