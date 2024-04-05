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
- `std::string reset()`<br>Resets the wallet.<br><br>
- `std::string set_log_level(int log_level)`<br>Sets the log level for the wallet.<br><br>
- `std::string get_version()`<br>Retrieves the version of the wallet.<br><br>
- `std::string get_wallet_files()`<br>Retrieves information about wallet files.<br><br>
- `std::string get_export_private_info(const std::string& target_dir)`<br>Retrieves private information and exports it to the specified directory.<br><br>
- `std::string delete_wallet(const std::string& file_name)`<br>Deletes the wallet with the specified file name.<br><br>
- `std::string get_address_info(const std::string& addr)`<br>Retrieves information about a specific address.<br><br>

### Configuration Functions
- `std::string get_appconfig(const std::string& encryption_key)`<br>Retrieves the application configuration using the specified encryption key, used for application level secure config storing.<br><br>
- `std::string set_appconfig(const std::string& conf_str, const std::string& encryption_key)`<br>Sets the application configuration using the specified configuration string and encryption key.<br><br>
- `std::string generate_random_key(uint64_t length)`<br>Generates a random key of the specified length(by using a secure random generation algorithms).<br><br>
- `std::string get_logs_buffer()`<br>Retrieves the logs buffer, userful for debugging.<br><br>
- `std::string truncate_log()`<br>Truncates the log.<br><br>
- `std::string get_connectivity_status()`<br>Retrieves the connectivity status.<br><br>

### Wallet Management Functions
- `std::string open(const std::string& path, const std::string& password)`<br>Opens a wallet from the specified path using the provided password, the path is relative to the app wallet home dir.<br><br>
- `std::string restore(const std::string& seed, const std::string& path, const std::string& password, const std::string& seed_password)`<br>Restores a wallet using the provided seed, path, password, and seed password(optional).<br><br>
- `std::string generate(const std::string& path, const std::string& password)`<br>Generates a new wallet at the specified path with the provided password.<br><br>
- `std::string get_opened_wallets()`<br>Retrieves information about opened wallets with it's handles.<br><br>

### Wallet Operations
- `std::string get_wallet_status(hwallet h)`<br>Retrieves the status of the wallet with the specified handle.<br><br>
- `std::string close_wallet(hwallet h)`<br>Closes the wallet with the specified handle.<br><br>
- `std::string invoke(hwallet h, const std::string& params)`<br>Invokes an JSON RPC on the wallet with the specified handle and parameters(basically JSON RPC).<br><br>

### Asynchronous API Functions
- `std::string async_call(const std::string& method_name, uint64_t instance_id, const std::string& params)`<br>Initiates an asynchronous RPC call to a method with the specified name, instance ID, and parameters. Return request_id, and result should be fetched with try_pull_result() by passing given request_id.<br><br>
- `std::string try_pull_result(uint64_t)`<br>Tries to pull the result of a previous asynchronous call.<br><br>
- `std::string sync_call(const std::string& method_name, uint64_t instance_id, const std::string& params)`<br>Initiates a synchronous RPC call to a method with the specified name, instance ID, and parameters.<br><br>

### Cake Wallet API Extension
- `bool is_wallet_exist(const std::string& path)`<br>Checks if a wallet exists at the specified path.<br><br>
- `std::string get_wallet_info(hwallet h)`<br>Retrieves information about the wallet with the specified handle.<br><br>
- `std::string reset_wallet_password(hwallet h, const std::string& password)`<br>Resets the password of the wallet with the specified handle.<br><br>
- `uint64_t get_current_tx_fee(uint64_t priority)`<br>Retrieves the current transaction fee based on priority.<br><br>
