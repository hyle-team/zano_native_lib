@echo off
setlocal enabledelayedexpansion

:: Get the absolute path for PROJECT_ROOT
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%..\..\.."
set "PROJECT_ROOT=%CD%"
popd

:: Get the absolute path for OPENSSL_DIR
set "OPENSSL_DIR=%PROJECT_ROOT%\thirdparty\openssl\windows"

:: Run the build for x86_64
call :BUILD x86_64
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

:: Run the build for arm64 (Commented out as in original)
:: call :BUILD arm64

:: source build-macosx-arm64/VERSION.dat equivalent
if exist "build-macosx-arm64\VERSION.dat" (
    for /f "usebackq delims=" %%a in ("build-macosx-arm64\VERSION.dat") do set "%%a"
    echo !MAJOR!.!MINOR!.!PATCH! > "%OPENSSL_DIR%\VERSION"
)

goto :EOF

:BUILD
set "ARCH=%~1"

:: Architecture validation
if not "%ARCH%"=="arm64" if not "%ARCH%"=="x86_64" (
    echo ERROR: Unsupported architecture: '%ARCH%' >&2
    exit /b 1
)

set "BUILD_ROOT=%OPENSSL_DIR%\build-windows-%ARCH%"

echo Preparing build folder: %BUILD_ROOT%

:: Call the download script
call "%PROJECT_ROOT%\thirdparty\openssl\download-openssl.bat" "%BUILD_ROOT%"
if %ERRORLEVEL% neq 0 exit /b 1

pushd "%BUILD_ROOT%"

:: Setup Configure Flags
set "CONFIGURE_FLAGS=no-shared no-tests"
if "%ARCH%"=="arm64" (
    set "CONFIGURE_FLAGS=!CONFIGURE_FLAGS! VC-WIN64-ARM"
) else if "%ARCH%"=="x86_64" (
    set "CONFIGURE_FLAGS=!CONFIGURE_FLAGS! VC-WIN64A"
)

:: Run Perl Configure
perl Configure !CONFIGURE_FLAGS!
if %ERRORLEVEL% neq 0 ( popd & exit /b 1 )

:: Run nmake
nmake
if %ERRORLEVEL% neq 0 ( popd & exit /b 1 )

:: Clean old include and lib folders
if exist "%OPENSSL_DIR%\include" rd /s /q "%OPENSSL_DIR%\include"
if exist "%OPENSSL_DIR%\lib\%ARCH%" rd /s /q "%OPENSSL_DIR%\lib\%ARCH%"

:: Create target directory
if not exist "%OPENSSL_DIR%\lib\%ARCH%" mkdir "%OPENSSL_DIR%\lib\%ARCH%"

:: Copy library files
copy /Y "%BUILD_ROOT%\*.lib" "%OPENSSL_DIR%\lib\%ARCH%\"

:: Copy include directory recursively
xcopy /S /E /Y /Q "include" "%OPENSSL_DIR%\include\"

popd
exit /b 0
