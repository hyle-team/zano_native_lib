@echo off
setlocal enabledelayedexpansion

:: Arguments mapping
set "LIB_NAME=%~1"
set "LIB_TAR_URL=%~2"
set "LIB_TAR_HASH=%~3"
set "STORE_DIR=%~4"
set "TARGET_DIR=%~5"

:: Extract filename from URL
for %%i in ("%LIB_TAR_URL%") do set "LIB_TAR_NAME=%%~nxi"

echo %LIB_NAME% version: %LIB_TAR_NAME%

:: 1. Download if not exists
if not exist "%STORE_DIR%\%LIB_TAR_NAME%" (
    echo Downloading %LIB_NAME% tarball: '%LIB_TAR_URL%'
    curl -L "%LIB_TAR_URL%" -o "%STORE_DIR%\%LIB_TAR_NAME%"
)

:: 2. Verify Hash
:: Certutil outputs hash in uppercase with spaces; we strip them
set "TEMP_HASH_FILE=%TEMP%\hash_%RANDOM%.txt"
certutil -hashfile "%STORE_DIR%\%LIB_TAR_NAME%" SHA256 | findstr /v ":" > "%TEMP_HASH_FILE%"
set /p RAW_HASH=<"%TEMP_HASH_FILE%"
set "ACTUAL_HASH=%RAW_HASH: =%"
del "%TEMP_HASH_FILE%"

:: Convert expected hash to uppercase for comparison (Certutil output is uppercase)
powershell -Command "$('%LIB_TAR_HASH%').ToUpper()" > "%TEMP_HASH_FILE%"
set /p EXPECTED_HASH=<"%TEMP_HASH_FILE%"
del "%TEMP_HASH_FILE%"

if /I "!ACTUAL_HASH!" neq "!EXPECTED_HASH!" (
    echo ERROR: %LIB_NAME% tarball does not satisfy provided hash.
    echo  Expected: %LIB_TAR_HASH%
    echo    Actual: %ACTUAL_HASH%
    echo Deleting this tarball.
    del /q "%STORE_DIR%\%LIB_TAR_NAME%"
    exit /b 1
)

:: 3. Extraction
if exist "%TARGET_DIR%" rd /s /q "%TARGET_DIR%"
mkdir "%TARGET_DIR%"
echo Extracting...
tar -xzf "%STORE_DIR%\%LIB_TAR_NAME%" -C "%TARGET_DIR%"

:: 4. Flatten directory if single subdirectory exists
:: Check if there's exactly one directory inside TARGET_DIR
set "DIR_COUNT=0"
for /f "delims=" %%i in ('dir /b /ad "%TARGET_DIR%"') do (
    set /a DIR_COUNT+=1
    set "SUB_DIR=%%i"
)
set "FILE_COUNT=0"
for /f "delims=" %%i in ('dir /b /a-d "%TARGET_DIR%"') do set /a FILE_COUNT+=1

if %DIR_COUNT% equ 1 if %FILE_COUNT% equ 0 (
    echo Flattening directory structure...
    :: Use PowerShell for the move to correctly handle hidden files (mimics dotglob)
    powershell -Command "Move-Item -Path '%TARGET_DIR%\%SUB_DIR%\*' -Destination '%TARGET_DIR%' -Force"
    rd /s /q "%TARGET_DIR%\%SUB_DIR%"
)

exit /b 0
