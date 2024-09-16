
# Zano Wallet Library (native) for mobile platforms (ios/android)

To build ios run build_ios_libs.sh script, and as a result will be xcframworks libraries assembled in _install_ios/lib folder, include it all in xcode project Build Phases -> Link Binary With Libraries

To build Android libraries run build_android_libs.sh script, a result will be built to _install_android 


# Wallet Library API Documentation

## Namespace: `plain_wallet`

### Typedef
- `hwallet`<br>A type representing a wallet handle, defined as `int64_t`.

### Initialization Functions
- `std::string init(const std::string& address, const std::string& working_dir, int log_level)`<br>Initializes the wallet using the specified address(http://127.0.0.1:2222), working directory, and log level.<br><br>
- `std::string init(const std::string& ip, const std::string& port, const std::string& working_dir, int log_level)`<br>Initializes the wallet using the specified IP address, port, working directory, and log level.<br><br>

### Utility Functions
- `std::string reset()`<br>Quicly close all opened wallets(withut saving files).<br><br>
- `std::string set_log_level(int log_level)`<br>Sets the log level for the wallet.(default is 0, -1 disabled)<br><br>
- `std::string get_version()`<br>Retrieves the version string of the wallet library. <br>Returns: `2.0.0.317[2f535f0]`<br><br>
- `std::string get_wallet_files()`<br>Retrieves list of wallet files contained in app working folder, returned as JSON strings array.<br>Response:
```json
 {
  "items": [
    "11.newtmp_1723818128",
    "3wetw",
    "te",
    "23",
    "test1",
    "weq",
    "234",
    "11",
    "111",
    "1"
  ]
}
```
<br><br>
- `std::string get_export_private_info(const std::string& target_dir)`<br>Retrieves private information and exports it to the specified directory.<br><br>
- `std::string delete_wallet(const std::string& file_name)`<br>Deletes the wallet with the specified file name.<br>Response:
```json
{
  "id": 0,
  "jsonrpc": "",
  "result": {
    "return_code": "OK"
  }
}
```
<br><br>
- `std::string get_address_info(const std::string& addr)`<br>Retrieves information about a specific address, validate it.<br>**Example:** 
`get_address_info("ZxDQxh9WKrzKPAzJLubti7BiidsnrvDNHbwDjAAXPnrtSVX4Mfc51ZiUafLMdMDBL54mp9J25mZxkGjLQxizxzbX1JzGyRbW5")`
<br>**Response:** 
```json
{
  "valid": true,
  "auditable": false,
  "payment_id": false,
  "wrap": false
}
```
<br><br>
### Configuration Functions

- `std::string set_appconfig(const std::string& conf_str, const std::string& encryption_key)` <br>Sets the application configuration an a free text form (common way to store it in JSON) using the specified configuration string and encryption key. This text is encrypted and stored in application system folder. Might be used to storing list of opened wallet files and it's passwords. <br><br>
- `std::string get_appconfig(const std::string& encryption_key)`<br>Retrieves the application configuration using the specified encryption key, used for application level secure config storing.<br><br>

- `std::string generate_random_key(uint64_t length)`<br>Generates a random string of the specified length(by using a secure random generation algorithms). Used secure random algorithm. <br><br>
- `std::string get_logs_buffer()`<br>Retrieves the logs buffer, userful for debugging.<br><br>
- `std::string truncate_log()`<br>Truncates the log file.<br><br>
- `std::string get_connectivity_status()`<br>Retrieves the connectivity status.<br>Response:
```json
{
  "is_online": true,
  "is_server_busy": false,
  "last_daemon_is_disconnected": false,
  "last_proxy_communicate_timestamp": 1726314483
}
```
<br>
<br>

### Wallet Management Functions
- `std::string open(const std::string& path, const std::string& password)`<br>Opens a wallet from the specified path using the provided password, the path is relative to the app wallet home dir. This is synchronous function, recommend to use async form of this call by calling 
`async_api_call('open', 0, {path: "file_name", pass: "password"});`
Response: 
```json
{
    "id": 0,
    "jsonrpc": "",
    "result": {
        "name": "",
        "pass": "",
        "recent_history": {
            "last_item_index": 0,
            "total_history_items": 0
        },
        "recovered": false,
        "seed": "invite invite invite invite invite invite invite invite invite invite invite invite invite invite invite invite invite invite limb total season behind burden after hour please",
        "wallet_file_size": 597,
        "wallet_id": 1,
        "wallet_local_bc_size": 2809794,
        "wi": {
            "address": "ZxBkXtnk5NA1X7VDdetzUyQsvHtn6E5KfGax32JdGwghabhYYRSpdJnQEdtkvyLHLogoQFXs2MqJTSnHhazLPwf92bXtw4vup",
            "balances": [...],
            "has_bare_unspent_outputs": false,
            "is_auditable": false,
            "is_watch_only": false,
            "mined_total": 0,
            "path": "/data/user/0/com.zano_mobile/files/wallets/1",
            "view_sec_key": "815f67e73733773fa249eb58787b1efbe3cd2c7306fe54834f929de7e0aa1205"
        }
    }
}
```
<br><br>
- `std::string restore(const std::string& seed, const std::string& path, const std::string& password, const std::string& seed_password)`<br>Restores a wallet using the provided seed (and seed's password if it's secured seed). Restored wallet saved to **path**, and encrypted with **password**.<br>Response: 
```json
{
  "id": 0,
  "jsonrpc": "",
  "result": {
    "name": "",
    "pass": "",
    "recent_history": {
      "last_item_index": 0,
      "total_history_items": 0
    },
    "recovered": false,
    "seed": "invite invite invite invite invite invite invite invite invite invite terror funny money answer handle inner scream cream limb total season behind burden after hour please",
    "wallet_file_size": 0,
    "wallet_id": 1,
    "wallet_local_bc_size": 0,
    "wi": {
      "address": "ZxBkXtnk5NA1X7VDdetzUyQsvHtn6E5KfGax32JdGwghabhYYRSpdJnQEdtkvyLHLogoQFXs2MqJTSnHhazLPwf92bXtw4vup",
      "balances": [
        {
          "asset_info": {
            "asset_id": "d6329b5b1f7c0805b5c345f4957554002a2f557845f64d7645dae0e051a6498a",
            "current_supply": 0,
            "decimal_point": 12,
            "full_name": "Zano",
            "hidden_supply": false,
            "meta_info": "",
            "owner": "0000000000000000000000000000000000000000000000000000000000000000",
            "ticker": "ZANO",
            "total_max_supply": 0
          },
          "awaiting_in": 0,
          "awaiting_out": 0,
          "total": 0,
          "unlocked": 0
        }
      ],
      "has_bare_unspent_outputs": false,
      "is_auditable": false,
      "is_watch_only": false,
      "mined_total": 0,
      "path": "/data/user/0/com.zano_mobile/files/wallets/11111",
      "view_sec_key": "815f67e73fc1fedfa249eb5878773efbe3cd233306fe54834f929de7e0aa1205"
    }
  }
}
```
<br><br>
- `std::string generate(const std::string& path, const std::string& password)`<br>Generates a new wallet at the specified **path** with the provided **password**.
Response: 
```json
{
  "id": 0,
  "jsonrpc": "",
  "result": {
    "name": "",
    "pass": "",
    "recent_history": {
      "last_item_index": 0,
      "total_history_items": 0
    },
    "recovered": false,
    "seed": "invite invite invite invite invite invite invite invite invite invite invite funny money answer handle inner scream cream limb total season behind burden after hour please",
    "wallet_file_size": 0,
    "wallet_id": 0,
    "wallet_local_bc_size": 0,
    "wi": {
      "address": "ZxBkXtnk5NA1X7VDdetzUyQsvHtn6E5KfGax32JdGwghabhYYRSpdJnQEdtkvyLHLogoQFXs2MqJTSnHhazLPwf92bXtw4vup",
      "balances": [
        {
          "asset_info": {
            "asset_id": "d6329b5b1f7c0805b5c345f4957554002a2f557845f64d7645dae0e051a6498a",
            "current_supply": 0,
            "decimal_point": 12,
            "full_name": "Zano",
            "hidden_supply": false,
            "meta_info": "",
            "owner": "0000000000000000000000000000000000000000000000000000000000000000",
            "ticker": "ZANO",
            "total_max_supply": 0
          },
          "awaiting_in": 0,
          "awaiting_out": 0,
          "total": 0,
          "unlocked": 0
        }
      ],
      "has_bare_unspent_outputs": false,
      "is_auditable": false,
      "is_watch_only": false,
      "mined_total": 0,
      "path": "/data/user/0/com.zano_mobile/files/wallets/1",
      "view_sec_key": "815f67e73fc1fedfa249eb58787b1efbe3cd233306fe54834f929de7e0aa1205"
    }
  }
}
```
<br><br>
- `std::string get_opened_wallets()`<br>Retrieves list of currently opened wallets with it's handles(**wallet_id**). Response: 
```json
{
  "id": 0,
  "jsonrpc": "",
  "result": [
    {
      "name": "1",
      "pass": "1",
      "recent_history": {
        "last_item_index": 0,
        "total_history_items": 0
      },
      "recovered": false,
      "seed": "",
      "wallet_file_size": 597,
      "wallet_id": 1,
      "wallet_local_bc_size": 2809799,
      "wi": {
        "address": "ZxBkXtnk5NA1X7VDdetzUyQsvHtn6E5KfGax32JdGwghabhYYRSpdJnQEdtkvyLHLogoQFXs2MqJTSnHhazLPwf92bXtw4vup",
        "balances": [
          {
            "asset_info": {
              "asset_id": "d6329b5b1f7c0805b5c345f4957554002a2f557845f64d7645dae0e051a6498a",
              "current_supply": 0,
              "decimal_point": 12,
              "full_name": "Zano",
              "hidden_supply": false,
              "meta_info": "",
              "owner": "0000000000000000000000000000000000000000000000000000000000000000",
              "ticker": "ZANO",
              "total_max_supply": 0
            },
            "awaiting_in": 0,
            "awaiting_out": 0,
            "total": 0,
            "unlocked": 0
          }
        ],
        "has_bare_unspent_outputs": false,
        "is_auditable": false,
        "is_watch_only": false,
        "mined_total": 0,
        "path": "/data/user/0/com.zano_mobile/files/wallets/1",
        "view_sec_key": "815f67e73fc1fedfa249eb58787b1efbe3cd2ccc06fe54834f929de7e0aa1205"
      }
    }
  ]
}
```
<br><br>

### Wallet Operations
- `std::string get_wallet_status(hwallet h)`<br>Retrieves the status of the wallet with the specified handle. Response: 
```json
{
  "current_daemon_height": 2809788,
  "current_wallet_height": 2282031,
  "is_daemon_connected": true,
  "is_in_long_refresh": true,
  "progress": 0,
  "wallet_state": 1
}
```

<br><br>
- `std::string close_wallet(hwallet h)`<br>Closes the wallet with the specified handle. This is synchronous function, recommend to use async form of this call by calling 
`async_api_call('close', wallet_id, '');`
Response: 
```json
{
	"return_code": "OK"
}
```
<br><br>
- `std::string invoke(hwallet h, const std::string& params)`<br>Basically invokes an call to the wallet native library by using JSON RPC format, documented in the official wallet RPC documentation. This call normally don't do any network communications, it's just JSON-based gateway to wallet native library. It's recommended yo use this via **async_api_call** method to avoid lags with heavy calls. Example: 
`await async_api_call( 'invoke', 0, "{ \"method\": \"store\", }");`
This example calls **"invoke"** api of this library, for the wallet with handle 0, and pass string `"{ \"method\": \"store\", }"` to this "invoke" as argument, which address wallet RPC method "store". Method "store"  might be heavy and time consuming, for that reason it's called by using **async_api_call**
<br><br>

### Asynchronous API Functions
- `std::string async_call(const std::string& method_name, uint64_t wallet_id, const std::string& params)`<br>Initiates an asynchronous call of on of the following functions: 
	- "**close**"
	- "**open**",
	- "**restore**"
	- "**get_seed_phrase_info**",
	- "**invoke**" (this is proxy to wallet JSON RPC API, documented in the official documentation)
	- "**get_wallet_status**"

Return job_id, and result should be fetched with **try_pull_result()** by passing given job_id, normally **try_pull_result()** is done in the background with some reasonable sleep interval around 100 ms.
```json
{
  "job_id": 4093
}
```

<br><br>
- `std::string try_pull_result(uint64_t job_id)`<br>Tries to pull the result of a previous asynchronous call.<br><br>
- `std::string sync_call(const std::string& method_name, uint64_t instance_id, const std::string& params)`<br>This is internal function and normally not used by front end.<br><br>

### Cake Wallet API Extension
- `bool is_wallet_exist(const std::string& path)`<br>Checks if a wallet exists at the specified path.<br><br>
- `std::string get_wallet_info(hwallet h)`<br>Retrieves extended information about the wallet with the specified handle(including secret keys and seed).<br><br>
- `std::string reset_wallet_password(hwallet h, const std::string& password)`<br>Resets the password of the wallet with the specified handle.<br><br>
- `uint64_t get_current_tx_fee(uint64_t priority)`<br>Retrieves the current transaction fee based on priority.<br><br>
