@echo off
chcp 65001 >nul
title BANNARAKX NETFORGE - DNS back to automatic
net session >nul 2>&1
if errorlevel 1 goto :elevate
goto :main
:elevate
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b
:main
echo.
echo   Returning DNS to Automatic (DHCP) on all adapters ...
echo   Note: this does not bring back a static DNS you set by hand earlier.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetAdapter -Physical | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses; Write-Host ('  [OK] ' + $_.InterfaceDescription) }; ipconfig /flushdns | Out-Null"
echo.
pause
