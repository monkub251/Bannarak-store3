@echo off
chcp 65001 >nul
title BANNARAKX NETFORGE - DNS 1.1.1.1 / 1.0.0.1
net session >nul 2>&1
if errorlevel 1 goto :elevate
goto :main
:elevate
powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b
:main
echo.
echo   Setting DNS = 1.1.1.1 / 1.0.0.1 on every active adapter ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$n=@(Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Bluetooth' }); if ($n.Count -eq 0) { Write-Host '  [X] No active adapter found'; exit 1 }; foreach ($a in $n) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses '1.1.1.1','1.0.0.1'; Write-Host ('  [OK] ' + $a.InterfaceDescription) }; ipconfig /flushdns | Out-Null"
echo.
pause
