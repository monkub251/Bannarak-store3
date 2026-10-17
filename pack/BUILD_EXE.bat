@echo off
title BANNARAKX NETFORGE - BUILD EXE
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" goto :nocsc

set "ICON="
if exist "%~dp0src\netforge.ico" set "ICON=/win32icon:%~dp0src\netforge.ico"

echo.
echo   Building BANNARAKX_NETFORGE.exe and BANNARAKX_ULTIMATE.exe ...
"%CSC%" /nologo /target:exe /platform:anycpu /optimize+ /out:"%~dp0BANNARAKX_NETFORGE.exe" /win32manifest:"%~dp0src\app.manifest" %ICON% "%~dp0src\Launcher.cs"
if errorlevel 1 goto :fail
"%CSC%" /nologo /target:exe /platform:anycpu /optimize+ /out:"%~dp0BANNARAKX_ULTIMATE.exe" /win32manifest:"%~dp0src\app.manifest" %ICON% "%~dp0src\Launcher.cs"
if errorlevel 1 goto :fail

echo.
echo   [OK] Created: BANNARAKX_NETFORGE.exe   (network only)
echo   [OK] Created: BANNARAKX_ULTIMATE.exe   (everything - recommended)
echo        Double-click it to run (asks for Administrator).
echo.
pause
exit /b 0

:nocsc
echo.
echo   [X] .NET Framework 4 compiler (csc.exe) was not found on this PC.
echo.
pause
exit /b 1

:fail
echo.
echo   [X] Build failed. Check the messages above.
echo.
pause
exit /b 1
