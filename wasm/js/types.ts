/**
 * Zano WASM Wallet Library - TypeScript Type Definitions
 * Copyright (c) 2014-2025 Zano Project
 *
 * Complete type definitions for the Zano wallet WASM interface
 */

// ============================================================================
// Asset and Balance Types
// ============================================================================

export interface AssetInfo {
  asset_id: string;
  ticker: string;
  full_name: string;
  decimal_point: number;
  total_max_supply: number;
  current_supply: number;
  hidden_supply: boolean;
  meta_info: string;
  owner: string;
}

export interface Balance {
  asset_info: AssetInfo;
  total: number;
  unlocked: number;
  awaiting_in: number;
  awaiting_out: number;
}

// ============================================================================
// Wallet Types
// ============================================================================

export interface WalletInfo {
  wallet_id: number;
  address: string;
  path: string;
  seed?: string;  // Only included on generate/restore
  view_sec_key: string;
  balances: Balance[];
  is_watch_only: boolean;
  is_auditable: boolean;
  has_bare_unspent_outputs: boolean;
  mined_total: number;
  wallet_file_size: number;
  wallet_local_bc_size: number;
  name?: string;
  pass?: string;
  recovered: boolean;
}

export interface RecentHistory {
  last_item_index: number;
  total_history_items: number;
}

export interface WalletStatus {
  wallet_state: number;  // 0=error, 1=syncing, 2=ready
  current_wallet_height: number;
  current_daemon_height: number;
  is_daemon_connected: boolean;
  is_in_long_refresh: boolean;
  progress: number;  // 0-100
}

export interface ConnectivityStatus {
  is_online: boolean;
  is_server_busy: boolean;
  last_daemon_is_disconnected: boolean;
  last_proxy_communicate_timestamp: number;
}

export interface AddressInfo {
  valid: boolean;
  auditable: boolean;
  payment_id: boolean;
  wrap: boolean;
}

// ============================================================================
// Transaction Types
// ============================================================================

export interface TransferDestination {
  address: string;
  amount: number;
  asset_id?: string;
}

export interface Transfer {
  destinations: TransferDestination[];
  fee: number;
  mixin: number;
  payment_id?: string;
  comment?: string;
  push_payer?: boolean;
  hide_receiver?: boolean;
}

// ============================================================================
// Async Job Pattern Types
// ============================================================================

export interface JobResponse {
  job_id: number;
}

export interface JobResult<T = any> {
  status?: 'working' | 'completed' | 'error';
  result?: T;
  error?: string;
  job_id: number;
}

// ============================================================================
// API Response Types
// ============================================================================

export interface ApiResponse<T = any> {
  id?: number;
  jsonrpc?: string;
  result?: T;
  error?: {
    code: number;
    message: string;
  };
}

export interface ReturnCode {
  return_code: 'OK' | 'ERROR' | string;
  error_code?: number;
  error_message?: string;
}

// ============================================================================
// Configuration Types
// ============================================================================

export interface WalletFilesResponse {
  items: string[];
}

export interface VersionInfo {
  version: string;
  build_number: number;
  commit_id?: string;
}

// ============================================================================
// Main API Interface
// ============================================================================

export interface ZanoWalletAPI {
  // Initialization
  init(daemonUrl: string, workdir?: string, logLevel?: number): Promise<ApiResponse>;
  reset(): Promise<ReturnCode>;

  // Wallet Lifecycle
  generate(path: string, password: string): Promise<WalletInfo>;
  restore(seed: string, path: string, password: string, seedPassword?: string): Promise<WalletInfo>;
  open(path: string, password: string): Promise<WalletInfo>;
  close(walletId: number): Promise<ReturnCode>;

  // Wallet Operations
  getStatus(walletId: number): Promise<WalletStatus>;
  getInfo(walletId: number): Promise<WalletInfo>;
  invoke(walletId: number, params: any): Promise<ApiResponse>;

  // Async Operations
  asyncCall(method: string, walletId: number, params: any): Promise<number>;
  pullResult(jobId: number): Promise<JobResult>;
  waitForJob<T = any>(jobId: number, pollMs?: number, timeoutMs?: number): Promise<T>;

  // Utilities
  getVersion(): Promise<string>;
  getWalletFiles(): Promise<string[]>;
  getAddressInfo(address: string): Promise<AddressInfo>;
  getConnectivity(): Promise<ConnectivityStatus>;
  generateRandomKey(length: number): Promise<string>;

  // Storage Management
  flush(): Promise<void>;

  // Cleanup
  terminate(): void;
}

// ============================================================================
// Worker Message Types
// ============================================================================

export interface WorkerMessage {
  id: number;
  type: string;
  payload?: any;
}

export interface WorkerResponse {
  id: number;
  type: string;
  result?: any;
  error?: string;
}

// ============================================================================
// Configuration Options
// ============================================================================

export interface WalletConfig {
  daemonUrl: string;
  workdir?: string;
  logLevel?: number;
  workerUrl?: string;
}

// ============================================================================
// Event Types
// ============================================================================

export type WalletEventType =
  | 'initialized'
  | 'wallet_opened'
  | 'wallet_closed'
  | 'sync_progress'
  | 'new_block'
  | 'transaction'
  | 'error';

export interface WalletEvent {
  type: WalletEventType;
  data: any;
  timestamp: number;
}

export type WalletEventHandler = (event: WalletEvent) => void;

// ============================================================================
// Error Types
// ============================================================================

export class ZanoWalletError extends Error {
  code?: number;
  details?: any;

  constructor(message: string, code?: number, details?: any) {
    super(message);
    this.name = 'ZanoWalletError';
    this.code = code;
    this.details = details;
  }
}

export class NetworkError extends ZanoWalletError {
  constructor(message: string, details?: any) {
    super(message, 1001, details);
    this.name = 'NetworkError';
  }
}

export class WalletNotFoundError extends ZanoWalletError {
  constructor(path: string) {
    super(`Wallet not found: ${path}`, 1002, { path });
    this.name = 'WalletNotFoundError';
  }
}

export class InvalidPasswordError extends ZanoWalletError {
  constructor() {
    super('Invalid wallet password', 1003);
    this.name = 'InvalidPasswordError';
  }
}

export class JobTimeoutError extends ZanoWalletError {
  constructor(jobId: number, timeoutMs: number) {
    super(`Job ${jobId} timed out after ${timeoutMs}ms`, 1004, { jobId, timeoutMs });
    this.name = 'JobTimeoutError';
  }
}
