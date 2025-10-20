// Copyright (c) 2014-2025 Zano Project
// WASM C API Wrapper for plain_wallet
// Distributed under the MIT/X11 software license

#pragma once
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ========================================================================
// Initialization & Configuration
// ========================================================================

/**
 * Initialize the wallet library with daemon address
 * @param daemon_url Full daemon URL (e.g., "http://127.0.0.1:11211")
 * @param workdir Working directory for wallet files
 * @param log_level Log level (0=minimal, 4=debug, -1=disabled)
 * @return JSON string with initialization result
 */
const char* pw_init(const char* daemon_url, const char* workdir, int log_level);

/**
 * Initialize with separate IP and port
 * @param ip Daemon IP address
 * @param port Daemon port
 * @param workdir Working directory
 * @param log_level Log level
 * @return JSON string with initialization result
 */
const char* pw_init_ip_port(const char* ip, const char* port, const char* workdir, int log_level);

/**
 * Reset the wallet system (closes all wallets without saving)
 * @return JSON string with status
 */
const char* pw_reset();

/**
 * Set logging level
 * @param log_level New log level
 * @return JSON string with status
 */
const char* pw_set_log_level(int log_level);

/**
 * Get library version
 * @return JSON string with version info
 */
const char* pw_get_version();

// ========================================================================
// Wallet File Management
// ========================================================================

/**
 * Get list of wallet files in working directory
 * @return JSON string with array of wallet filenames
 */
const char* pw_get_wallet_files();

/**
 * Delete a wallet file
 * @param file_name Wallet filename (relative to working directory)
 * @return JSON string with status
 */
const char* pw_delete_wallet(const char* file_name);

/**
 * Check if wallet file exists
 * @param path Wallet path
 * @return true if wallet exists, false otherwise
 */
bool pw_is_wallet_exist(const char* path);

/**
 * Export private information to target directory
 * @param target_dir Target directory for export
 * @return JSON string with status
 */
const char* pw_get_export_private_info(const char* target_dir);

// ========================================================================
// Application Configuration (Encrypted Storage)
// ========================================================================

/**
 * Get application configuration (encrypted with key)
 * @param encryption_key Encryption key for config
 * @return JSON string with decrypted config
 */
const char* pw_get_appconfig(const char* encryption_key);

/**
 * Set application configuration (encrypted with key)
 * @param conf_str Configuration string to encrypt and store
 * @param encryption_key Encryption key
 * @return JSON string with status
 */
const char* pw_set_appconfig(const char* conf_str, const char* encryption_key);

// ========================================================================
// Utility Functions
// ========================================================================

/**
 * Generate cryptographically secure random key
 * @param length Length of key to generate
 * @return JSON string with random key
 */
const char* pw_generate_random_key(uint64_t length);

/**
 * Get logs buffer for debugging
 * @return JSON string with log content
 */
const char* pw_get_logs_buffer();

/**
 * Truncate log file
 * @return JSON string with status
 */
const char* pw_truncate_log();

/**
 * Get connectivity status with daemon
 * @return JSON string with connectivity info
 */
const char* pw_get_connectivity_status();

/**
 * Validate and get information about an address
 * @param addr Zano address to validate
 * @return JSON string with address info (valid, auditable, payment_id, wrap)
 */
const char* pw_get_address_info(const char* addr);

// ========================================================================
// Wallet Lifecycle
// ========================================================================

/**
 * Generate a new wallet
 * @param path Wallet filename (relative to working directory)
 * @param password Wallet password for encryption
 * @return JSON string with wallet info (includes seed phrase, wallet_id, address)
 */
const char* pw_generate(const char* path, const char* password);

/**
 * Restore wallet from seed phrase
 * @param seed BIP39-compatible seed phrase
 * @param path Wallet filename
 * @param password Wallet password
 * @param seed_password Optional seed password (use "" if none)
 * @return JSON string with restored wallet info
 */
const char* pw_restore(const char* seed, const char* path, const char* password, const char* seed_password);

/**
 * Open existing wallet
 * @param path Wallet filename
 * @param password Wallet password
 * @return JSON string with wallet info
 */
const char* pw_open(const char* path, const char* password);

/**
 * Close wallet by ID
 * @param wallet_id Wallet handle returned from open/generate/restore
 * @return JSON string with status
 */
const char* pw_close_wallet(int64_t wallet_id);

/**
 * Get list of currently opened wallets
 * @return JSON string with array of wallet info
 */
const char* pw_get_opened_wallets();

// ========================================================================
// Wallet Operations
// ========================================================================

/**
 * Get wallet status (sync progress, daemon connection, etc.)
 * @param wallet_id Wallet handle
 * @return JSON string with status info
 */
const char* pw_get_wallet_status(int64_t wallet_id);

/**
 * Get detailed wallet information (includes secret keys and seed)
 * @param wallet_id Wallet handle
 * @return JSON string with wallet details
 */
const char* pw_get_wallet_info(int64_t wallet_id);

/**
 * Reset wallet password
 * @param wallet_id Wallet handle
 * @param new_password New password
 * @return JSON string with status
 */
const char* pw_reset_wallet_password(int64_t wallet_id, const char* new_password);

/**
 * Invoke wallet JSON-RPC method
 * @param wallet_id Wallet handle
 * @param params JSON-RPC request string (e.g., {"method": "transfer", ...})
 * @return JSON string with JSON-RPC response
 */
const char* pw_invoke(int64_t wallet_id, const char* params);

/**
 * Get current transaction fee for priority level
 * @param priority Fee priority (0=default, 1=unimportant, 2=normal, 3=elevated, 4=priority)
 * @return Fee amount in atomic units
 */
uint64_t pw_get_current_tx_fee(uint64_t priority);

// ========================================================================
// Async Operations (Job Queue Pattern)
// ========================================================================

/**
 * Execute asynchronous operation (returns immediately with job_id)
 * Supported methods: "open", "close", "restore", "invoke", "get_wallet_status"
 * @param method_name Method to execute asynchronously
 * @param wallet_id Wallet handle (or 0 for wallet-independent methods)
 * @param params JSON string with method parameters
 * @return JSON string with job_id
 */
const char* pw_async_call(const char* method_name, int64_t wallet_id, const char* params);

/**
 * Try to pull result from async operation
 * @param job_id Job ID returned from pw_async_call
 * @return JSON string with result (or status if still working)
 */
const char* pw_try_pull_result(uint64_t job_id);

/**
 * Synchronous call (blocking version of async_call)
 * @param method_name Method to execute
 * @param instance_id Instance ID
 * @param params JSON parameters
 * @return JSON string with result
 */
const char* pw_sync_call(const char* method_name, uint64_t instance_id, const char* params);

// ========================================================================
// Memory Management
// ========================================================================

/**
 * Free memory allocated by C API
 * IMPORTANT: All const char* returned by pw_* functions must be freed using this
 * @param str String pointer to free
 */
void pw_free(const char* str);

#ifdef __cplusplus
}
#endif
