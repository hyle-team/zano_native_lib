@echo off
setlocal enabledelayedexpansion

:: Get PROJECT_ROOT
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%..\..\.."
set "PROJECT_ROOT=%CD%"
popd

:: Get BOOST_DIR
set "BOOST_DIR=%PROJECT_ROOT%\thirdparty\boost\windows"

:: Run BUILD for x86_64
call :BUILD x86_64
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

:: Run BUILD for arm64 (Commented out per original)
:: call :BUILD arm64

:: Get version
call "%PROJECT_ROOT%\thirdparty\boost\get-boost-version.bat" "%BOOST_DIR%\build-windows-x86_64" > "%BOOST_DIR%\VERSION"

goto :EOF

:BUILD
set "ARCH=%~1"

:: Architecture validation
if not "%ARCH%"=="arm64" if not "%ARCH%"=="x86_64" (
    echo ERROR: Unsupported architecture: '%ARCH%' >&2
    exit /b 1
)

set "BUILD_ROOT=%BOOST_DIR%\build-windows-%ARCH%"

echo Preparing build folder: %BUILD_ROOT%

:: Call download script
call "%PROJECT_ROOT%\thirdparty\boost\download-boost.bat" "%BUILD_ROOT%"
if %ERRORLEVEL% neq 0 exit /b 1

pushd "%BUILD_ROOT%"

:: Run bootstrap
call bootstrap.bat --with-libraries=atomic,chrono,date_time,filesystem,regex,serialization,system,thread,timer,program_options,locale,log
if %ERRORLEVEL% neq 0 ( popd & exit /b 1 )

:: Setup B2 Flags
set "B2_FLAGS=link=static toolset=msvc variant=release threading=multi runtime-link=shared address-model=64"

if "%ARCH%"=="arm64" (
    set "B2_FLAGS=!B2_FLAGS! architecture=arm"
) else (
    set "B2_FLAGS=!B2_FLAGS! architecture=x86"
)

:: Run B2
call b2.exe !B2_FLAGS! --with-atomic --with-chrono --with-date_time --with-filesystem --with-regex --with-serialization --with-system --with-thread --with-timer --with-program_options --with-locale --with-log stage
if %ERRORLEVEL% neq 0 ( popd & exit /b 1 )

:: Clean old include and lib folders
if exist "%BOOST_DIR%\include" rd /s /q "%BOOST_DIR%\include"
if exist "%BOOST_DIR%\lib\%ARCH%" rd /s /q "%BOOST_DIR%\lib\%ARCH%"

:: Create target directory
if not exist "%BOOST_DIR%\lib\%ARCH%" mkdir "%BOOST_DIR%\lib\%ARCH%"
if not exist "%BOOST_DIR%\include" mkdir "%BOOST_DIR%\include"

:: Copy library files
copy /Y "stage\lib\*.lib" "%BOOST_DIR%\lib\%ARCH%\"

:: Copy boost headers
:: Note: Boost headers are usually in a 'boost' subdirectory within the build root
xcopy /S /E /Y /Q "boost" "%BOOST_DIR%\include\boost\"

popd
exit /b 0
