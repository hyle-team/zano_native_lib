/**
 * Zano WASM Wallet Library - Main Thread API
 * Copyright (c) 2014-2025 Zano Project
 *
 * Public API for interacting with the Zano wallet WASM module
 * All operations are executed in a Web Worker for non-blocking UI
 */

import type {
    ZanoWalletAPI,
    WalletInfo,
    WalletStatus,
    ConnectivityStatus,
    AddressInfo,
    ApiResponse,
    ReturnCode,
    JobResult,
    WalletConfig,
    WalletEvent,
    WalletEventHandler,
    ZanoWalletError,
    JobTimeoutError,
    WorkerMessage,
    WorkerResponse
} from './types';

import { JobTimeoutError as JobTimeoutErrorClass } from './types';
/**
 * Zano Wallet WASM Client
 * Main interface for browser/Cordova/Electron applications
 */
export class ZanoWalletWasm implements ZanoWalletAPI {
    private worker: Worker;
    private messageId = 0;
    private pending = new Map<number, { resolve: (value: any) => void; reject: (reason: any) => void }>();
    private eventHandlers = new Map<string, Set<WalletEventHandler>>();
    private isInitialized = false;

    /**
     * Create a new Zano Wallet instance
     * @param workerUrl Path to worker.js file
     * @param wasmUrl Optional path to zano_wallet.wasm file
     */
    constructor(workerUrl: string, private wasmUrl?: string) {
        this.worker = new Worker(workerUrl, { type: 'module' });
        this.worker.onmessage = this.handleMessage.bind(this);
        this.worker.onerror = this.handleWorkerError.bind(this);
    }

    // ========================================================================
    // Private Helper Methods
    // ========================================================================

    private handleMessage(ev: MessageEvent<WorkerResponse>): void {
        const { id, type, result, error } = ev.data;

        // Check for event broadcasts (messages without pending request)
        if (type && type.startsWith('event_')) {
            this.emitEvent(type.substring(6), result);
            return;
        }

        // Handle pending request responses
        const handlers = this.pending.get(id);
        if (!handlers) {
            console.warn(`[ZanoWallet] Received response for unknown request ID: ${id}`);
            return;
        }

        this.pending.delete(id);

        if (error) {
            handlers.reject(new Error(error));
        } else {
            handlers.resolve(result);
        }
    }

    private handleWorkerError(error: ErrorEvent): void {
        console.error('[ZanoWallet] Worker error:', error);
        this.emitEvent('error', { message: error.message, error });
    }

    private call<T = any>(type: string, payload?: any): Promise<T> {
        return new Promise((resolve, reject) => {
            const id = ++this.messageId;
            this.pending.set(id, { resolve, reject });

            const message: WorkerMessage = { id, type, payload };
            this.worker.postMessage(message);
        });
    }

    private emitEvent(type: string, data: any): void {
        const handlers = this.eventHandlers.get(type);
        if (handlers) {
            const event: WalletEvent = {
                type: type as any,
                data,
                timestamp: Date.now()
            };
            handlers.forEach(handler => {
                try {
                    handler(event);
                } catch (err) {
                    console.error(`[ZanoWallet] Event handler error for "${type}":`, err);
                }
            });
        }
    }

    // ========================================================================
    // Event Management
    // ========================================================================

    /**
     * Subscribe to wallet events
     */
    on(eventType: string, handler: WalletEventHandler): void {
        if (!this.eventHandlers.has(eventType)) {
            this.eventHandlers.set(eventType, new Set());
        }
        this.eventHandlers.get(eventType)!.add(handler);
    }

    /**
     * Unsubscribe from wallet events
     */
    off(eventType: string, handler: WalletEventHandler): void {
        const handlers = this.eventHandlers.get(eventType);
        if (handlers) {
            handlers.delete(handler);
        }
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    /**
     * Load the WASM module (call before any other operations)
     */
    async loadModule(): Promise<void> {
        if (this.isInitialized) {
            return;
        }

        const result = await this.call('load_module', { wasmUrl: this.wasmUrl });
        this.isInitialized = true;
        this.emitEvent('initialized', result);
    }

    /**
     * Initialize wallet system with daemon connection
     */
    async init(daemonUrl: string, workdir = '/wallet', logLevel = 0): Promise<ApiResponse> {
        if (!this.isInitialized) {
            await this.loadModule();
        }
        return this.call('init', { daemonUrl, workdir, logLevel });
    }

    /**
     * Reset wallet system (close all wallets without saving)
     */
    async reset(): Promise<ReturnCode> {
        return this.call('reset');
    }

    // ========================================================================
    // Wallet Lifecycle
    // ========================================================================

    /**
     * Generate a new wallet
     */
    async generate(path: string, password: string): Promise<WalletInfo> {
        const response = await this.call<any>('generate', { path, password });
        if (response.error) {
            throw new Error(response.error);
        }
        this.emitEvent('wallet_opened', response.result || response);
        return response.result || response;
    }

    /**
     * Restore wallet from seed phrase
     */
    async restore(seed: string, path: string, password: string, seedPassword = ''): Promise<WalletInfo> {
        const response = await this.call<any>('restore', { seed, path, password, seedPassword });
        if (response.error) {
            throw new Error(response.error);
        }
        this.emitEvent('wallet_opened', response.result || response);
        return response.result || response;
    }

    /**
     * Open existing wallet
     */
    async open(path: string, password: string): Promise<WalletInfo> {
        const response = await this.call<any>('open', { path, password });
        if (response.error) {
            throw new Error(response.error);
        }
        this.emitEvent('wallet_opened', response.result || response);
        return response.result || response;
    }

    /**
     * Close wallet
     */
    async close(walletId: number): Promise<ReturnCode> {
        const result = await this.call<ReturnCode>('close_wallet', { walletId });
        this.emitEvent('wallet_closed', { walletId });
        return result;
    }

    // ========================================================================
    // Wallet Operations
    // ========================================================================

    /**
     * Get wallet synchronization status
     */
    async getStatus(walletId: number): Promise<WalletStatus> {
        return this.call('get_wallet_status', { walletId });
    }

    /**
     * Get detailed wallet information (includes secret keys)
     */
    async getInfo(walletId: number): Promise<WalletInfo> {
        return this.call('get_wallet_info', { walletId });
    }

    /**
     * Invoke wallet JSON-RPC method
     */
    async invoke(walletId: number, params: any): Promise<ApiResponse> {
        return this.call('invoke', { walletId, params });
    }

    /**
     * Get current transaction fee for priority level
     */
    async getCurrentTxFee(priority: number = 0): Promise<number> {
        return this.call('get_current_tx_fee', { priority });
    }

    // ========================================================================
    // Async Operations (Job Queue Pattern)
    // ========================================================================

    /**
     * Execute asynchronous operation
     * Returns job_id for polling with pullResult()
     */
    async asyncCall(method: string, walletId: number, params: any): Promise<number> {
        const response = await this.call<any>('async_call', { method, walletId, params });
        return response.job_id || response;
    }

    /**
     * Pull result from async operation
     */
    async pullResult(jobId: number): Promise<JobResult> {
        return this.call('try_pull_result', { jobId });
    }

    /**
     * Wait for async job to complete (polls automatically)
     * @param jobId Job ID from asyncCall()
     * @param pollMs Polling interval in milliseconds
     * @param timeoutMs Timeout in milliseconds (0 = no timeout)
     */
    async waitForJob<T = any>(jobId: number, pollMs = 100, timeoutMs = 60000): Promise<T> {
        const startTime = Date.now();

        while (true) {
            const result = await this.pullResult(jobId);

            // Check if completed
            if (result.status === 'completed') {
                return result.result;
            }

            // Check if error
            if (result.status === 'error') {
                throw new Error(result.error || 'Job failed');
            }

            // Check timeout
            if (timeoutMs > 0 && (Date.now() - startTime) >= timeoutMs) {
                throw new JobTimeoutErrorClass(jobId, timeoutMs);
            }

            // Wait before next poll
            await new Promise(resolve => setTimeout(resolve, pollMs));
        }
    }

    // ========================================================================
    // Utility Functions
    // ========================================================================

    /**
     * Get library version
     */
    async getVersion(): Promise<string> {
        return this.call('get_version');
    }

    /**
     * Get list of wallet files in working directory
     */
    async getWalletFiles(): Promise<string[]> {
        const response = await this.call<any>('get_wallet_files');
        return response.items || response;
    }

    /**
     * Delete wallet file
     */
    async deleteWallet(fileName: string): Promise<ReturnCode> {
        return this.call('delete_wallet', { fileName });
    }

    /**
     * Check if wallet file exists
     */
    async isWalletExist(path: string): Promise<boolean> {
        return this.call('is_wallet_exist', { path });
    }

    /**
     * Validate and get information about an address
     */
    async getAddressInfo(address: string): Promise<AddressInfo> {
        return this.call('get_address_info', { address });
    }

    /**
     * Get daemon connectivity status
     */
    async getConnectivity(): Promise<ConnectivityStatus> {
        return this.call('get_connectivity_status');
    }

    /**
     * Generate cryptographically secure random key
     */
    async generateRandomKey(length: number = 32): Promise<string> {
        return this.call('generate_random_key', { length });
    }

    /**
     * Get logs buffer for debugging
     */
    async getLogsBuffer(): Promise<string> {
        return this.call('get_logs_buffer');
    }

    /**
     * Truncate log file
     */
    async truncateLog(): Promise<ReturnCode> {
        return this.call('truncate_log');
    }

    // ========================================================================
    // Configuration
    // ========================================================================

    /**
     * Get encrypted application configuration
     */
    async getAppConfig(encryptionKey: string): Promise<string> {
        return this.call('get_appconfig', { encryptionKey });
    }

    /**
     * Set encrypted application configuration
     */
    async setAppConfig(confStr: string, encryptionKey: string): Promise<ReturnCode> {
        return this.call('set_appconfig', { confStr, encryptionKey });
    }

    // ========================================================================
    // Storage Management
    // ========================================================================

    /**
     * Flush wallet files to persistent storage (IndexedDB)
     * Call after important operations (wallet generation, transactions, etc.)
     */
    async flush(): Promise<void> {
        await this.call('flush');
    }

    /**
     * Sync file system from persistent storage
     * Useful after page reload to ensure latest data
     */
    async syncFS(): Promise<void> {
        await this.call('sync_fs');
    }

    // ========================================================================
    // Cleanup
    // ========================================================================

    /**
     * Terminate worker and cleanup resources
     */
    terminate(): void {
        this.worker.terminate();
        this.pending.clear();
        this.eventHandlers.clear();
        this.isInitialized = false;
    }
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Create and initialize a Zano wallet instance
 * Convenience function for quick setup
 */
export async function createZanoWallet(config: WalletConfig): Promise<ZanoWalletWasm> {
    const wallet = new ZanoWalletWasm(config.workerUrl || '/worker.js', config.daemonUrl);
    await wallet.init(config.daemonUrl, config.workdir, config.logLevel);
    return wallet;
}

/**
 * Export all types for external use
 */
export * from './types';
