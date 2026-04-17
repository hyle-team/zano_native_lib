@echo off
setlocal enabledelayedexpansion

:: PROJECT_ROOT=$(realpath "$(dirname $0)/..")
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_ROOT=%CD%"
popd

set "ARTIFACTS_ROOT=%PROJECT_ROOT%\windows"

:: BOOST_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/boost/windows/VERSION")
set /p BOOST_VERSION= < "%PROJECT_ROOT%\thirdparty\boost\windows\VERSION"
:: OPENSSL_VERSION=$(cat "${PROJECT_ROOT}/thirdparty/openssl/windows/VERSION")
set /p OPENSSL_VERSION= < "%PROJECT_ROOT%\thirdparty\openssl\windows\VERSION"

echo Boost Version:   %BOOST_VERSION%
echo OpenSSL Version: %OPENSSL_VERSION%
echo ===============================================================================
echo Building...

:: BUILD_TYPE=$1
set "BUILD_TYPE=%~1"
if "%BUILD_TYPE%"=="" set "BUILD_TYPE=Release"

:: BUILD x86_64
call :BUILD x86_64

:: # BUILD arm64

:: rm -rf "${ARTIFACTS_ROOT}"/include
if exist "%ARTIFACTS_ROOT%\include" rd /s /q "%ARTIFACTS_ROOT%\include"
:: mkdir -p "${ARTIFACTS_ROOT}"/include/
mkdir "%ARTIFACTS_ROOT%\include"
:: cp "${PROJECT_ROOT}"/Zano/src/wallet/*.h "${ARTIFACTS_ROOT}/include/"
copy /Y "%PROJECT_ROOT%\Zano\src\wallet\*.h" "%ARTIFACTS_ROOT%\include\"

:: "${PROJECT_ROOT}/scripts/zano-version.sh" "${ARTIFACTS_ROOT}/build-windows-arm64" > "${ARTIFACTS_ROOT}/VERSION"
call "%PROJECT_ROOT%\scripts\zano-version.bat" "%ARTIFACTS_ROOT%\build-windows-arm64" > "%ARTIFACTS_ROOT%\VERSION"

goto :EOF

:BUILD
set "ARCH=%~1"
set "BUILD_ROOT=%ARTIFACTS_ROOT%\build-windows-%ARCH%"
echo Building: windows %ARCH% in '%BUILD_ROOT%'

:: local ARCH_ARGS=... || exit 1
if "%ARCH%"=="x86_64" (
    set "ARCH_ARGS=-Ax64 -Thost=x64"
) else (
    exit 1
)

:: Boost_FATLIB semicolon expansion
set "BOOST_LIB_DIR=%PROJECT_ROOT%\thirdparty\boost\windows\lib\%ARCH%"
set "FATLIB_LIST="
for %%F in ("%BOOST_LIB_DIR%\libboost_*.lib") do (
    if defined FATLIB_LIST (
        set "FATLIB_LIST=!FATLIB_LIST!;%%F"
    ) else (
        set "FATLIB_LIST=%%F"
    )
)

:: cmake.exe ... || exit 1
cmake.exe -S"%PROJECT_ROOT%\Zano" -B"%BUILD_ROOT%" ^
    -Wno-dev ^
    -DCMAKE_TOOLCHAIN_FILE="%ARTIFACTS_ROOT%\windows-toolchain.cmake" ^
    -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
    -DOPENSSL_INCLUDE_DIR="%PROJECT_ROOT%\thirdparty\openssl\windows\include" ^
    -DOPENSSL_CRYPTO_LIBRARY="%PROJECT_ROOT%\thirdparty\openssl\windows\lib\%ARCH%\libcrypto.lib" ^
    -DOPENSSL_SSL_LIBRARY="%PROJECT_ROOT%\thirdparty\openssl\windows\lib\%ARCH%\libssl.lib" ^
    -DBoost_VERSION="Boost %BOOST_VERSION%" ^
    -DBoost_NO_SYSTEM_PATHS=ON ^
    -DBoost_USE_STATIC_LIBS=ON ^
    -DBoost_USE_STATIC_RUNTIME=OFF ^
    -DBOOST_ROOT="%PROJECT_ROOT%\thirdparty\boost\windows" ^
    -DBoost_FATLIB="%FATLIB_LIST%" ^
    -DBOOST_LIBRARYDIR="%BOOST_LIB_DIR%" ^
    -DBoost_LIBRARY_DIR="%BOOST_LIB_DIR%" ^
    -DBoost_LIBRARY_DIRS="%BOOST_LIB_DIR%" ^
    -DBOOST_INCLUDEDIR="%PROJECT_ROOT%\thirdparty\boost\windows\include" ^
    -DBoost_INCLUDE_DIR="%PROJECT_ROOT%\thirdparty\boost\windows\include" ^
    -DBoost_INCLUDE_DIRS="%PROJECT_ROOT%\thirdparty\boost\windows\include" ^
    -DTESTNET=FALSE ^
    -DUSE_PCH=TRUE ^
    -DBUILD_TESTS=FALSE ^
    -DDISABLE_TOR=TRUE ^
    %ARCH_ARGS% ^
    -G"Visual Studio 17 2022"
if %ERRORLEVEL% neq 0 exit 1

:: cmake --build "${BUILD_ROOT}" --config ${BUILD_TYPE}
cmake --build "%BUILD_ROOT%" --config %BUILD_TYPE%

:: for lib in ...; do if [ ! -f ... ]; then exit 1; fi; done
for %%L in (currency_core common crypto rpc stratum wallet pch) do (
    if not exist "%BUILD_ROOT%\src\Release\%%L.lib" (
        echo libzano failed to build windows %ARCH% %%L >&2
        exit 1
    )
)

:: rm -rf "${ARTIFACTS_ROOT}"/lib/${ARCH}
if exist "%ARTIFACTS_ROOT%\lib\%ARCH%" rd /s /q "%ARTIFACTS_ROOT%\lib\%ARCH%"
:: mkdir -p "${ARTIFACTS_ROOT}"/lib/${ARCH}
if not exist "%ARTIFACTS_ROOT%\lib\%ARCH%" mkdir "%ARTIFACTS_ROOT%\lib\%ARCH%"

:: cp "${BUILD_ROOT}"/src/Release/{...}.lib "${ARTIFACTS_ROOT}"/lib/${ARCH}/
for %%L in (currency_core common crypto rpc stratum wallet pch) do (
    copy /Y "%BUILD_ROOT%\src\Release\%%L.lib" "%ARTIFACTS_ROOT%\lib\%ARCH%\"
)

:: cp contrib libs
copy /Y "%BUILD_ROOT%\contrib\zlib\Release\zlibstatic.lib" "%ARTIFACTS_ROOT%\lib\%ARCH%\"
copy /Y "%BUILD_ROOT%\contrib\db\liblmdb\Release\lmdb.lib" "%ARTIFACTS_ROOT%\lib\%ARCH%\"
copy /Y "%BUILD_ROOT%\contrib\db\libmdbx\Release\mdbx.lib" "%ARTIFACTS_ROOT%\lib\%ARCH%\"
copy /Y "%BUILD_ROOT%\contrib\ethereum\libethash\Release\ethash.lib" "%ARTIFACTS_ROOT%\lib\%ARCH%\"
copy /Y "%BUILD_ROOT%\contrib\miniupnp\miniupnpc\Release\miniupnpc.lib" "%ARTIFACTS_ROOT%\lib\%ARCH%\"

exit /b 0
