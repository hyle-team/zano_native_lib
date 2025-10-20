// Copyright (c) 2014-2025 Zano Project
// WASM C API Wrapper Implementation
// Distributed under the MIT/X11 software license

#include "c_api.h"
#include "../../Zano/src/wallet/plain_wallet_api.h"
#include <cstring>
#include <cstdlib>
#include <mutex>
#include <string>

// Global mutex for thread-safe access
static std::mutex g_api_mutex;

// Helper function: Duplicate std::string to C string (caller must free with pw_free)
static const char* dup_str(const std::string& s) {
    if (s.empty()) {
        // Return empty string instead of null
        char* empty = (char*)malloc(1);
        empty[0] = '\0';
        return empty;
    }

    char* result = (char*)malloc(s.size() + 1);
    if (result == nullptr) {
        return nullptr;
    }

    memcpy(result, s.data(), s.size());
    result[s.size()] = '\0';
    return result;
}

// Helper function: Safe string conversion (null -> empty string)
static std::string safe_str(const char* str) {
    return str ? std::string(str) : std::string();
}

extern "C" {

// ========================================================================
// Initialization & Configuration
// ========================================================================

const char* pw_init(const char* daemon_url, const char* workdir, int log_level) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::init(safe_str(daemon_url), safe_str(workdir), log_level);
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_init"})");
    }
}

const char* pw_init_ip_port(const char* ip, const char* port, const char* workdir, int log_level) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::init(safe_str(ip), safe_str(port), safe_str(workdir), log_level);
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_init_ip_port"})");
    }
}

const char* pw_reset() {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::reset();
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_reset"})");
    }
}

const char* pw_set_log_level(int log_level) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::set_log_level(log_level);
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_set_log_level"})");
    }
}

const char* pw_get_version() {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_version();
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_version"})");
    }
}

// ========================================================================
// Wallet File Management
// ========================================================================

const char* pw_get_wallet_files() {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_wallet_files();
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_wallet_files"})");
    }
}

const char* pw_delete_wallet(const char* file_name) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::delete_wallet(safe_str(file_name));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_delete_wallet"})");
    }
}

bool pw_is_wallet_exist(const char* path) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        return plain_wallet::is_wallet_exist(safe_str(path));
    } catch (...) {
        return false;
    }
}

const char* pw_get_export_private_info(const char* target_dir) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_export_private_info(safe_str(target_dir));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_export_private_info"})");
    }
}

// ========================================================================
// Application Configuration (Encrypted Storage)
// ========================================================================

const char* pw_get_appconfig(const char* encryption_key) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_appconfig(safe_str(encryption_key));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_appconfig"})");
    }
}

const char* pw_set_appconfig(const char* conf_str, const char* encryption_key) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::set_appconfig(safe_str(conf_str), safe_str(encryption_key));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_set_appconfig"})");
    }
}

// ========================================================================
// Utility Functions
// ========================================================================

const char* pw_generate_random_key(uint64_t length) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::generate_random_key(length);
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_generate_random_key"})");
    }
}

const char* pw_get_logs_buffer() {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_logs_buffer();
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_logs_buffer"})");
    }
}

const char* pw_truncate_log() {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::truncate_log();
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_truncate_log"})");
    }
}

const char* pw_get_connectivity_status() {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_connectivity_status();
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_connectivity_status"})");
    }
}

const char* pw_get_address_info(const char* addr) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_address_info(safe_str(addr));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_address_info"})");
    }
}

// ========================================================================
// Wallet Lifecycle
// ========================================================================

const char* pw_generate(const char* path, const char* password) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::generate(safe_str(path), safe_str(password));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_generate"})");
    }
}

const char* pw_restore(const char* seed, const char* path, const char* password, const char* seed_password) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::restore(
            safe_str(seed),
            safe_str(path),
            safe_str(password),
            safe_str(seed_password)
        );
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_restore"})");
    }
}

const char* pw_open(const char* path, const char* password) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::open(safe_str(path), safe_str(password));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_open"})");
    }
}

const char* pw_close_wallet(int64_t wallet_id) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::close_wallet(wallet_id);
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_close_wallet"})");
    }
}

const char* pw_get_opened_wallets() {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_opened_wallets();
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_opened_wallets"})");
    }
}

// ========================================================================
// Wallet Operations
// ========================================================================

const char* pw_get_wallet_status(int64_t wallet_id) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_wallet_status(wallet_id);
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_wallet_status"})");
    }
}

const char* pw_get_wallet_info(int64_t wallet_id) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::get_wallet_info(wallet_id);
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_get_wallet_info"})");
    }
}

const char* pw_reset_wallet_password(int64_t wallet_id, const char* new_password) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::reset_wallet_password(wallet_id, safe_str(new_password));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_reset_wallet_password"})");
    }
}

const char* pw_invoke(int64_t wallet_id, const char* params) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::invoke(wallet_id, safe_str(params));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_invoke"})");
    }
}

uint64_t pw_get_current_tx_fee(uint64_t priority) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        return plain_wallet::get_current_tx_fee(priority);
    } catch (...) {
        return 0;  // Return 0 on error
    }
}

// ========================================================================
// Async Operations (Job Queue Pattern)
// ========================================================================

const char* pw_async_call(const char* method_name, int64_t wallet_id, const char* params) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::async_call(safe_str(method_name), wallet_id, safe_str(params));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_async_call"})");
    }
}

const char* pw_try_pull_result(uint64_t job_id) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::try_pull_result(job_id);
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_try_pull_result"})");
    }
}

const char* pw_sync_call(const char* method_name, uint64_t instance_id, const char* params) {
    std::lock_guard<std::mutex> lock(g_api_mutex);
    try {
        std::string result = plain_wallet::sync_call(safe_str(method_name), instance_id, safe_str(params));
        return dup_str(result);
    } catch (const std::exception& e) {
        std::string error = R"({"error": ")" + std::string(e.what()) + R"("})";
        return dup_str(error);
    } catch (...) {
        return dup_str(R"({"error": "Unknown exception in pw_sync_call"})");
    }
}

// ========================================================================
// Memory Management
// ========================================================================

void pw_free(const char* str) {
    if (str != nullptr) {
        free((void*)str);
    }
}

} // extern "C"
