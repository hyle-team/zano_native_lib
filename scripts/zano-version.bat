@echo off
setlocal enabledelayedexpansion

set "BUILD_PATH=%~1"

:: 1. Generate the files exactly as before
if not exist "%BUILD_PATH%\version" mkdir "%BUILD_PATH%\version"

echo. > "%BUILD_PATH%\version\misc_language.h"
echo #define STRINGIFY_EXPAND(s) STRINGIFY(s) >> "%BUILD_PATH%\version\misc_language.h"
echo #define STRINGIFY(s) #s >> "%BUILD_PATH%\version\misc_language.h"

echo. > "%BUILD_PATH%\version\version.c"
echo #include ^<stdio.h^> >> "%BUILD_PATH%\version\version.c"
echo #include "version.h" >> "%BUILD_PATH%\version\version.c"
echo int main() { >> "%BUILD_PATH%\version\version.c"
echo   printf(PROJECT_VERSION_LONG); >> "%BUILD_PATH%\version\version.c"
echo   return 0; >> "%BUILD_PATH%\version\version.c"
echo } >> "%BUILD_PATH%\version\version.c"

echo [DEBUG] Compiling version extractor for host execution...
cl /nologo "%BUILD_PATH%\version\version.c" /I"%BUILD_PATH%\version" /Fe:"%BUILD_PATH%\version\version.exe" /Fo:"%BUILD_PATH%\version\version.obj"

if not exist "%BUILD_PATH%\version\version.exe" (
    echo [ERROR] version.exe was never created by the compiler.
    exit /b 1
)

:: 4. Run it
"%BUILD_PATH%\version\version.exe"
