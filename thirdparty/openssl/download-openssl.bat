@echo off
setlocal enabledelayedexpansion

set "SCRIPT_ROOT=%~dp0"
pushd "%SCRIPT_ROOT%..\..\"
set "ROOT=%CD%"
popd

if "%OPENSSL_VERSION%"=="" set "OPENSSL_VERSION=3.1.8"
if "%OPENSSL_TAR_HASH%"=="" set "OPENSSL_TAR_HASH=d319da6aecde3aa6f426b44bbf997406d95275c5c59ab6f6ef53caaa079f456f"
if "%OPENSSL_TAR_URL%"=="" (
    set "OPENSSL_TAR_URL=https://github.com/openssl/openssl/releases/download/openssl-%OPENSSL_VERSION%/openssl-%OPENSSL_VERSION%.tar.gz"
)

set "TARGET_DIR=%~1"

call "%ROOT%\scripts\download-tar.bat" OpenSSL "%OPENSSL_TAR_URL%" "%OPENSSL_TAR_HASH%" "%SCRIPT_ROOT%" "%TARGET_DIR%"
if %ERRORLEVEL% neq 0 exit /b 1
