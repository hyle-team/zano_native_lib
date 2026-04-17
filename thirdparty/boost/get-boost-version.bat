@echo off
setlocal enabledelayedexpansion

set "BUILD_PATH=%~1\boost"

echo #include ^<stdio.h^> > "%BUILD_PATH%\version.c"
echo #include "version.hpp" >> "%BUILD_PATH%\version.c"
echo int main() { >> "%BUILD_PATH%\version.c"
echo   int major = BOOST_VERSION / 100000, minor = BOOST_VERSION / 100 %% 1000, patch = BOOST_VERSION %% 100; >> "%BUILD_PATH%\version.c"
echo   printf("%%d.%%d.%%d", major, minor, patch); >> "%BUILD_PATH%\version.c"
echo   return 0; >> "%BUILD_PATH%\version.c"
echo } >> "%BUILD_PATH%\version.c"

cl /nologo "%BUILD_PATH%\version.c" /I"%BUILD_PATH%" /Fe:"%BUILD_PATH%\version.exe" /Fo:"%BUILD_PATH%\version.obj" >NUL 2>&1

"%BUILD_PATH%\version.exe"
