/**
 * Zano WASM Wallet Library - Web Worker
 * Copyright (c) 2014-2025 Zano Project
 *
 * Web Worker that loads and manages the WASM module
 * Handles all communication between main thread and WASM library
 */

import type { WorkerMessage, WorkerResponse } from './types';

// Import the Emscripten-generated module
// Note: Path will be '../_install/zano_wallet.js' after build
declare function createZanoWalletModule(config?: any): Promise<any>;

let Module: any = null;
let moduleReady = false;

/**
 * Helper: Parse JSON response from C API
 * Many C API functions return JSON strings
 */
function parseJsonResponse(jsonStr: string): any {
    try {
        return JSON.parse(jsonStr);
    } catch (e) {
        // If not JSON, return as-is (e.g., version string)
        return jsonStr;
    }
}

/**
 * Helper: Call C function and handle response
 */
function callCFunction(funcName: string, returnType: string, argTypes: string[], args: any[]): any {
    if (!Module || !moduleReady) {
        throw new Error('WASM module not initialized');
    }

    const result = Module.ccall(funcName, returnType, argTypes, args);

    // If result is a string pointer, parse it and free memory
    if (returnType === 'string' && result) {
        const parsed = parseJsonResponse(result);
        // Note: Emscripten ccall with 'string' type handles memory automatically
        return parsed;
    }

    return result;
}

/**
 * Message handler from main thread
 */
self.onmessage = async (ev: MessageEvent<WorkerMessage>) => {
    const { id, type, payload } = ev.data;

    try {
        let result: any;

        switch (type) {
            // ================================================================
            // Module Initialization
            // ================================================================

            case 'load_module': {
                if (moduleReady) {
                    result = { status: 'already_loaded' };
                    break;
                }

                // Load WASM module
                Module = await createZanoWalletModule({
                    locateFile: (path: string) => {
                        // Help Emscripten find the .wasm file
                        if (path.endsWith('.wasm')) {
                            return payload.wasmUrl || path;
                        }
                        return path;
                    },
                    print: (text: string) => {
                        console.log('[WASM]', text);
                    },
                    printErr: (text: string) => {
                        console.error('[WASM Error]', text);
                    }
                });

                // Mount IDBFS for persistent storage
                Module.FS.mkdir('/wallet');
                Module.FS.mount(Module.FS.filesystems.IDBFS, {}, '/wallet');

                // Load existing files from IndexedDB
                await new Promise<void>((resolve, reject) => {
                    Module.FS.syncfs(true, (err: any) => {
                        if (err) {
                            console.warn('IDBFS sync error (may be first run):', err);
                            resolve(); // Don't fail on first run
                        } else {
                            resolve();
                        }
                    });
                });

                moduleReady = true;
                result = { status: 'loaded', version: Module._pw_get_version ? callCFunction('pw_get_version', 'string', [], []) : 'unknown' };
                break;
            }

            // ================================================================
            // Initialization & Configuration
            // ================================================================

            case 'init': {
                const { daemonUrl, workdir = '/wallet', logLevel = 0 } = payload;
                result = callCFunction('pw_init', 'string', ['string', 'string', 'number'], [daemonUrl, workdir, logLevel]);
                break;
            }

            case 'reset': {
                result = callCFunction('pw_reset', 'string', [], []);
                break;
            }

            case 'set_log_level': {
                result = callCFunction('pw_set_log_level', 'string', ['number'], [payload.logLevel]);
                break;
            }

            case 'get_version': {
                result = callCFunction('pw_get_version', 'string', [], []);
                break;
            }

            // ================================================================
            // Wallet Lifecycle
            // ================================================================

            case 'generate': {
                const { path, password } = payload;
                result = callCFunction('pw_generate', 'string', ['string', 'string'], [path, password]);
                break;
            }

            case 'restore': {
                const { seed, path, password, seedPassword = '' } = payload;
                result = callCFunction('pw_restore', 'string', ['string', 'string', 'string', 'string'], [seed, path, password, seedPassword]);
                break;
            }

            case 'open': {
                const { path, password } = payload;
                result = callCFunction('pw_open', 'string', ['string', 'string'], [path, password]);
                break;
            }

            case 'close_wallet': {
                result = callCFunction('pw_close_wallet', 'string', ['number'], [payload.walletId]);
                break;
            }

            case 'get_opened_wallets': {
                result = callCFunction('pw_get_opened_wallets', 'string', [], []);
                break;
            }

            // ================================================================
            // Wallet Operations
            // ================================================================

            case 'get_wallet_status': {
                result = callCFunction('pw_get_wallet_status', 'string', ['number'], [payload.walletId]);
                break;
            }

            case 'get_wallet_info': {
                result = callCFunction('pw_get_wallet_info', 'string', ['number'], [payload.walletId]);
                break;
            }

            case 'reset_wallet_password': {
                const { walletId, newPassword } = payload;
                result = callCFunction('pw_reset_wallet_password', 'string', ['number', 'string'], [walletId, newPassword]);
                break;
            }

            case 'invoke': {
                const { walletId, params } = payload;
                const paramsStr = typeof params === 'string' ? params : JSON.stringify(params);
                result = callCFunction('pw_invoke', 'string', ['number', 'string'], [walletId, paramsStr]);
                break;
            }

            case 'get_current_tx_fee': {
                result = callCFunction('pw_get_current_tx_fee', 'number', ['number'], [payload.priority || 0]);
                break;
            }

            // ================================================================
            // Async Operations
            // ================================================================

            case 'async_call': {
                const { method, walletId, params } = payload;
                const paramsStr = typeof params === 'string' ? params : JSON.stringify(params);
                result = callCFunction('pw_async_call', 'string', ['string', 'number', 'string'], [method, walletId, paramsStr]);
                break;
            }

            case 'try_pull_result': {
                result = callCFunction('pw_try_pull_result', 'string', ['number'], [payload.jobId]);
                break;
            }

            case 'sync_call': {
                const { method, instanceId, params } = payload;
                const paramsStr = typeof params === 'string' ? params : JSON.stringify(params);
                result = callCFunction('pw_sync_call', 'string', ['string', 'number', 'string'], [method, instanceId, paramsStr]);
                break;
            }

            // ================================================================
            // Utility Functions
            // ================================================================

            case 'get_wallet_files': {
                result = callCFunction('pw_get_wallet_files', 'string', [], []);
                break;
            }

            case 'delete_wallet': {
                result = callCFunction('pw_delete_wallet', 'string', ['string'], [payload.fileName]);
                break;
            }

            case 'is_wallet_exist': {
                result = callCFunction('pw_is_wallet_exist', 'boolean', ['string'], [payload.path]);
                break;
            }

            case 'get_address_info': {
                result = callCFunction('pw_get_address_info', 'string', ['string'], [payload.address]);
                break;
            }

            case 'get_connectivity_status': {
                result = callCFunction('pw_get_connectivity_status', 'string', [], []);
                break;
            }

            case 'generate_random_key': {
                result = callCFunction('pw_generate_random_key', 'string', ['number'], [payload.length || 32]);
                break;
            }

            case 'get_logs_buffer': {
                result = callCFunction('pw_get_logs_buffer', 'string', [], []);
                break;
            }

            case 'truncate_log': {
                result = callCFunction('pw_truncate_log', 'string', [], []);
                break;
            }

            // ================================================================
            // Configuration
            // ================================================================

            case 'get_appconfig': {
                result = callCFunction('pw_get_appconfig', 'string', ['string'], [payload.encryptionKey]);
                break;
            }

            case 'set_appconfig': {
                const { confStr, encryptionKey } = payload;
                result = callCFunction('pw_set_appconfig', 'string', ['string', 'string'], [confStr, encryptionKey]);
                break;
            }

            // ================================================================
            // Storage Management
            // ================================================================

            case 'flush': {
                // Flush IDBFS to IndexedDB
                await new Promise<void>((resolve, reject) => {
                    Module.FS.syncfs(false, (err: any) => {
                        if (err) {
                            reject(new Error(`IDBFS flush failed: ${err}`));
                        } else {
                            resolve();
                        }
                    });
                });
                result = { status: 'flushed' };
                break;
            }

            case 'sync_fs': {
                // Sync IDBFS (load from IndexedDB)
                await new Promise<void>((resolve, reject) => {
                    Module.FS.syncfs(true, (err: any) => {
                        if (err) {
                            reject(new Error(`IDBFS sync failed: ${err}`));
                        } else {
                            resolve();
                        }
                    });
                });
                result = { status: 'synced' };
                break;
            }

            // ================================================================
            // Unknown Command
            // ================================================================

            default: {
                throw new Error(`Unknown worker command: ${type}`);
            }
        }

        // Send success response
        const response: WorkerResponse = {
            id,
            type,
            result
        };
        self.postMessage(response);

    } catch (error: any) {
        // Send error response
        const response: WorkerResponse = {
            id,
            type,
            error: error.message || String(error)
        };
        self.postMessage(response);
    }
};

// Handle worker errors
self.onerror = (error) => {
    console.error('[Worker Error]', error);
};

// Ready signal
console.log('[Zano WASM Worker] Ready');
