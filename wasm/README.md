# Zano Wallet WASM Library

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.3-blue.svg)](https://www.typescriptlang.org/)
[![WebAssembly](https://img.shields.io/badge/WebAssembly-1.0-purple.svg)](https://webassembly.org/)

**Non-custodial Zano cryptocurrency wallet for web browsers, Chrome extensions, and Electron apps**

[Features](#features) • [Installation](#installation) • [Quick Start](#quick-start) • [API Documentation](#api-documentation) • [Examples](#examples) • [Security](#security)

</div>

---

## Features

- ✅ **Full Wallet Functionality** - Generate, restore, open wallets from browser
- 🔐 **Non-Custodial** - Private keys never leave the client
- 🚀 **High Performance** - Native C++ code compiled to WebAssembly
- 💾 **Persistent Storage** - IndexedDB integration for wallet file persistence
- 🔄 **Async Job Queue** - Non-blocking operations with progress tracking
- 🌐 **Cross-Platform** - Works in Chrome extensions, Cordova apps, Electron, and web browsers
- 📦 **TypeScript Support** - Full type definitions included
- 🔒 **Privacy-Focused** - Ring signatures, CLSAG, and Zarcanum proofs

## Installation

### NPM Package

```bash
npm install @zelcore/zano-wallet-wasm
```

### Direct Files

Download the latest release and include:
- `zano_wallet.js` - Emscripten loader
- `zano_wallet.wasm` - WebAssembly module
- `worker.js` - Web Worker (compiled from TypeScript)

## Quick Start

### Basic Usage

```typescript
import { ZanoWalletWasm } from '@zelcore/zano-wallet-wasm';

// Create wallet instance
const wallet = new ZanoWalletWasm('/worker.js');

// Initialize with daemon connection
await wallet.init('https://your-zano-daemon.example.com:11211');

// Generate new wallet
const walletInfo = await wallet.generate('my_wallet', 'secure_password');
console.log('Address:', walletInfo.address);
console.log('Seed phrase:', walletInfo.seed);

// Restore from seed
const restored = await wallet.restore(
  'seed phrase words here...',
  'restored_wallet',
  'password',
  ''
);

// Get wallet status
const status = await wallet.getStatus(walletInfo.wallet_id);
console.log('Sync progress:', status.progress, '%');

// Send transaction (async pattern)
const jobId = await wallet.asyncCall('transfer', walletInfo.wallet_id, {
  destinations: [{
    address: 'ZxRecipient...',
    amount: 1000000000000  // 1 ZANO (12 decimals)
  }],
  fee: 10000000000,  // 0.01 ZANO
  mixin: 10
});

// Wait for transaction to complete
const result = await wallet.waitForJob(jobId);
console.log('Transaction ID:', result.tx_hash);

// Persist to IndexedDB
await wallet.flush();
```

### Chrome Extension (MV3)

**manifest.json:**
```json
{
  "manifest_version": 3,
  "name": "Zano Wallet Extension",
  "permissions": ["storage"],
  "host_permissions": ["https://your-daemon.example.com/*"],
  "cross_origin_embedder_policy": {
    "value": "require-corp"
  },
  "cross_origin_opener_policy": {
    "value": "same-origin"
  },
  "web_accessible_resources": [{
    "resources": ["zano_wallet.wasm", "worker.js"],
    "matches": ["<all_urls>"]
  }]
}
```

**Extension code:**
```typescript
import { createZanoWallet } from '@zelcore/zano-wallet-wasm';

const wallet = await createZanoWallet({
  daemonUrl: 'https://your-daemon.example.com:11211',
  workerUrl: chrome.runtime.getURL('worker.js')
});
```

### Cordova Mobile App

```typescript
import { ZanoWalletWasm } from '@zelcore/zano-wallet-wasm';

// Single-threaded build for WebView
const wallet = new ZanoWalletWasm('./worker.js');
await wallet.init('https://your-daemon.example.com:11211');

// Use persistent storage
await wallet.flush();  // Persist after important operations
```

## API Documentation

### Initialization

#### `new ZanoWalletWasm(workerUrl, wasmUrl?)`
Create wallet instance.

#### `loadModule(): Promise<void>`
Load WASM module (called automatically by `init`).

#### `init(daemonUrl, workdir?, logLevel?): Promise<ApiResponse>`
Initialize wallet system with daemon connection.

**Parameters:**
- `daemonUrl` - Zano daemon URL (e.g., `https://daemon.zano.org:11211`)
- `workdir` - Working directory for wallet files (default: `/wallet`)
- `logLevel` - Log level 0-4 (default: 0)

### Wallet Lifecycle

#### `generate(path, password): Promise<WalletInfo>`
Generate new wallet.

**Returns:** Wallet info including `seed` phrase, `address`, and `wallet_id`

#### `restore(seed, path, password, seedPassword?): Promise<WalletInfo>`
Restore wallet from seed phrase.

#### `open(path, password): Promise<WalletInfo>`
Open existing wallet.

#### `close(walletId): Promise<ReturnCode>`
Close wallet.

### Wallet Operations

#### `getStatus(walletId): Promise<WalletStatus>`
Get wallet synchronization status.

**Returns:**
```typescript
{
  wallet_state: number;  // 0=error, 1=syncing, 2=ready
  current_wallet_height: number;
  current_daemon_height: number;
  is_daemon_connected: boolean;
  progress: number;  // 0-100
}
```

#### `invoke(walletId, params): Promise<ApiResponse>`
Invoke wallet JSON-RPC method.

**Example - Get balance:**
```typescript
const response = await wallet.invoke(walletId, {
  method: 'getbalance'
});
```

**Example - Transfer:**
```typescript
const response = await wallet.invoke(walletId, {
  method: 'transfer',
  params: {
    destinations: [{ address: '...', amount: 1000000000000 }],
    fee: 10000000000,
    mixin: 10
  }
});
```

### Async Operations

#### `asyncCall(method, walletId, params): Promise<number>`
Execute async operation, returns `job_id`.

#### `pullResult(jobId): Promise<JobResult>`
Check job status.

#### `waitForJob<T>(jobId, pollMs?, timeoutMs?): Promise<T>`
Wait for job completion with automatic polling.

**Parameters:**
- `pollMs` - Polling interval (default: 100ms)
- `timeoutMs` - Timeout (default: 60000ms, 0 = no timeout)

### Utilities

#### `getVersion(): Promise<string>`
Get library version.

#### `getWalletFiles(): Promise<string[]>`
List wallet files.

#### `getAddressInfo(address): Promise<AddressInfo>`
Validate address.

**Returns:**
```typescript
{
  valid: boolean;
  auditable: boolean;
  payment_id: boolean;
  wrap: boolean;
}
```

#### `getConnectivity(): Promise<ConnectivityStatus>`
Check daemon connectivity.

#### `generateRandomKey(length?): Promise<string>`
Generate secure random key.

### Storage Management

#### `flush(): Promise<void>`
Flush wallet files to IndexedDB (call after important operations).

#### `syncFS(): Promise<void>`
Sync from IndexedDB (useful after page reload).

### Event Handling

#### `on(eventType, handler): void`
Subscribe to events.

**Events:**
- `initialized` - Module loaded
- `wallet_opened` - Wallet opened/generated/restored
- `wallet_closed` - Wallet closed
- `sync_progress` - Sync progress update
- `error` - Error occurred

**Example:**
```typescript
wallet.on('sync_progress', (event) => {
  console.log('Sync:', event.data.progress, '%');
});

wallet.on('error', (event) => {
  console.error('Error:', event.data.message);
});
```

## Examples

### Complete Wallet Application

See `examples/demo.html` for a complete browser-based wallet demo.

### Integration Examples

- **Chrome Extension:** `examples/chrome-extension/`
- **Cordova App:** `examples/cordova-app/`
- **Electron App:** `examples/electron-app/`

## Platform-Specific Notes

### Chrome Extension (MV3)

- Run WASM in extension **page**, not service worker
- Set `cross_origin_embedder_policy` and `cross_origin_opener_policy` in manifest
- Optionally enable pthreads for better performance

### Cordova (iOS/Android)

- Use single-threaded build (WebView limitation)
- Add daemon URL to Content Security Policy
- Enforce TLS 1.2+ for iOS ATS compliance

### Electron

- Run WASM in renderer or dedicated worker
- Can use native file system via IPC if needed

## Security

### Best Practices

✅ **DO:**
- Run your own Zano daemon with TLS and CORS restrictions
- Use strong wallet passwords
- Call `flush()` after important operations
- Validate user input before passing to wallet API
- Implement rate limiting on wallet operations

❌ **DON'T:**
- Expose wallet RPC server publicly (use daemon RPC only)
- Log or transmit seed phrases or private keys
- Use public daemons in production
- Store passwords in plaintext

### Private Key Security

- Private keys are **never exposed to JavaScript**
- Keys remain in WASM memory space
- Wallet files are encrypted with ChaCha8
- Use CSP to prevent XSS attacks

## Building from Source

### Prerequisites

**System Requirements:**
- Linux or macOS (Windows users: use WSL2)
- CMake >= 3.16
- Emscripten SDK >= 3.1.45
- Boost >= 1.75
- OpenSSL 1.1.1w

**Install dependencies (Ubuntu/Debian):**
```bash
sudo apt-get install -y build-essential g++ curl autotools-dev libicu-dev libbz2-dev cmake git screen checkinstall zlib1g-dev libssl-dev bzip2
```

### Build Steps

```bash
# 1. Install Emscripten SDK
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh

# 2. Build Boost (following Zano pattern)
# Download Boost 1.84.0
wget https://archives.boost.io/release/1.84.0/source/boost_1_84_0.tar.gz
tar -xzf boost_1_84_0.tar.gz
cd boost_1_84_0

# Create Emscripten toolchain configuration
cat > tools/build/src/user-config.jam << 'EOF'
import os ;
using clang : emscripten
    : em++
    : <cxxflags>-fPIC
      <cflags>-fPIC
      <archiver>emar
      <ranlib>emranlib
    ;
EOF

# Bootstrap and build with Emscripten
./bootstrap.sh --with-libraries=system,filesystem,thread,date_time,chrono,regex,serialization,atomic,program_options,locale,timer,log
./b2 toolset=clang-emscripten link=static threading=single variant=release -j4
./b2 toolset=clang-emscripten link=static threading=single variant=release install --prefix=$HOME/boost_emscripten

# 3. Build OpenSSL (following Zano pattern)
# Download OpenSSL 1.1.1w
wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz
tar -xzf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w

# Configure and build with Emscripten
CC=emcc AR=emar RANLIB=emranlib ./Configure linux-generic32 \
  --prefix=$HOME/openssl \
  --openssldir=$HOME/openssl \
  no-shared \
  no-asm \
  no-threads \
  no-engine \
  no-hw \
  no-sock \
  -D__STDC_NO_ATOMICS__=1

emmake make -j4
emmake make install

# 4. Build WASM module
cd zano_native_lib/wasm
export BOOST_ROOT=/path/to/boost_1_84_0
export OPENSSL_ROOT_DIR=$HOME/openssl
./build-wasm.sh
```

## Troubleshooting

### "EMSDK not found"
```bash
source /path/to/emsdk/emsdk_env.sh
```

### "clang++-emscripten not found" when building Boost
This error occurs because Boost.Build doesn't have a built-in Emscripten toolchain. The solution is to create a `user-config.jam` file (see Build Steps above). Make sure you:
1. Activate Emscripten: `source /path/to/emsdk/emsdk_env.sh`
2. Create `tools/build/src/user-config.jam` in the Boost directory with the configuration shown in Build Steps
3. Use the correct build flags: `./b2 toolset=clang-emscripten link=static threading=single variant=release -j4`

### "Could NOT find OpenSSL" or "Could NOT find Boost"
Set the environment variables before building:
```bash
export OPENSSL_ROOT_DIR=$HOME/openssl
export BOOST_ROOT=$HOME/boost_emscripten
```

### "QuotaExceeded" error
Browser storage full. User needs to clear space or export wallet file for backup.

### Slow wallet sync
- Use threaded build if possible (Chrome extension with COOP/COEP)
- Consider pre-synced wallet file
- Implement progress UI to keep user informed

### CORS errors
Ensure daemon has proper CORS headers:
```
Access-Control-Allow-Origin: https://your-app.example.com
Access-Control-Allow-Methods: POST, OPTIONS
Access-Control-Allow-Headers: content-type
```

## Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **Issues:** https://github.com/zelcore/zano-wallet-wasm/issues
- **Zano Docs:** https://docs.zano.org/
- **Zano Discord:** https://discord.gg/zano

---

<div align="center">

**Built with ❤️ by the ZelCore team**

[Website](https://zel.network/) • [Twitter](https://twitter.com/zelcash) • [Discord](https://discord.gg/zelcash)

</div>
