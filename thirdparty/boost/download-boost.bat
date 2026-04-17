@echo off
setlocal enabledelayedexpansion

:: Get the directory of the current script
set "SCRIPT_ROOT=%~dp0"
:: Resolve ROOT (../../)
pushd "%SCRIPT_ROOT%..\..\"
set "ROOT=%CD%"
popd

:: Set defaults if variables are not already defined
if "%BOOST_VERSION%"=="" set "BOOST_VERSION=1.84.0"
if "%BOOST_TAR_HASH%"=="" set "BOOST_TAR_HASH=a5800f405508f5df8114558ca9855d2640a2de8f0445f051fa1c7c3383045724"

:: Replace dots with underscores in BOOST_VERSION for the URL
set "VERSION_UNDERSCORE=%BOOST_VERSION:.=_%"

if "%BOOST_TAR_URL%"=="" (
    set "BOOST_TAR_URL=https://archives.boost.io/release/%BOOST_VERSION%/source/boost_%VERSION_UNDERSCORE%.tar.gz"
)

:: %1 is the TARGET_DIR passed to this script
set "TARGET_DIR=%~1"

:: Call the download script (converted to .bat)
echo Downloading Boost...
call "%ROOT%\scripts\download-tar.bat" "Boost" "%BOOST_TAR_URL%" "%BOOST_TAR_HASH%" "%SCRIPT_ROOT%" "%TARGET_DIR%"
if %ERRORLEVEL% neq 0 (
    echo Error: Download failed.
    exit /b 1
)

:: Patch the file
:: Windows Git installation usually includes patch.exe in the path.
echo Patching build.sh...
patch "%TARGET_DIR%\tools\build\src\engine\build.sh" "%SCRIPT_ROOT%no-warnings.patch"

exit /b 0
