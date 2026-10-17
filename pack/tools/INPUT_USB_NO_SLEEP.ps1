# ================================================================================
#  BANNARAKX NETFORGE  ::  INPUT USB / HID NO-SLEEP
#  ปิดโหมดประหยัดไฟของเมาส์ / คีย์บอร์ด / USB ทุกตัวที่ต่ออยู่ (ลดอาการหน่วงตอนเริ่มขยับ)
#  - Backup ค่าเดิมก่อนแก้ ( -Restore คืนค่า )   - ต้องรีสตาร์ทหรือถอด/เสียบอุปกรณ์ใหม่
#  - ไม่แตะไฟล์ APEX เดิม
# ================================================================================
param([switch]$Restore, [switch]$NoReboot)

$ErrorActionPreference = 'SilentlyContinue'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if (-not $PSCommandPath) { Write-Host '  [X] Save as .ps1 and run from the file' -ForegroundColor Red; Read-Host | Out-Null; exit 1 }
    $argl = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
    if ($Restore)  { $argl += ' -Restore' }
    if ($NoReboot) { $argl += ' -NoReboot' }
    try { Start-Process -FilePath 'powershell.exe' -ArgumentList $argl -Verb RunAs | Out-Null } catch { Write-Host '  [X] Administrator rights are required' -ForegroundColor Red; Read-Host | Out-Null }
    exit
}

try { $r = $Host.UI.RawUI; $r.BackgroundColor = 'Black'; $r.ForegroundColor = 'Gray'; $r.WindowTitle = 'BANNARAKX NETFORGE :: INPUT USB/HID NO-SLEEP' } catch {}
try { Clear-Host } catch {}

$Root = Join-Path $env:ProgramData 'BannarakxNetForge'
$Bak  = Join-Path $Root 'usb_backup.json'
New-Item -ItemType Directory -Path $Root -Force | Out-Null

function P { param([string]$T, [string]$C = 'White', [switch]$NoNL) Write-Host $T -ForegroundColor $C -NoNewline:$NoNL }

P ''
P '   B A N N A R A K X   N E T F O R G E' 'Magenta'
P '   INPUT  USB / HID  NO-SLEEP' 'Cyan'
P ''

$names = @('EnhancedPowerManagementEnabled', 'AllowIdleIrpInD3', 'SelectiveSuspendEnabled', 'EnableSelectiveSuspend')

function Get-DevKeys {
    $out = New-Object System.Collections.ArrayList
    foreach ($cls in @('USB', 'HID')) {
        $base = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + $cls
        foreach ($dev in @(Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue)) {
            foreach ($inst in @(Get-ChildItem -LiteralPath $dev.PSPath -ErrorAction SilentlyContinue)) {
                $dp = Join-Path $inst.PSPath 'Device Parameters'
                if (Test-Path -LiteralPath $dp) { [void]$out.Add($dp) }
            }
        }
    }
    return ,$out
}

if ($Restore) {
    if (-not (Test-Path -LiteralPath $Bak)) { P '   No backup found - nothing to restore' 'Yellow'; Read-Host | Out-Null; exit }
    $d = Get-Content -LiteralPath $Bak -Raw -Encoding UTF8 | ConvertFrom-Json
    $n = 0
    foreach ($e in @($d.Items)) {
        if (-not $e) { continue }
        try {
            if ($e.Exists) { Set-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value ([int]$e.Value) -Type DWord -ErrorAction Stop }
            else { Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -Force -ErrorAction SilentlyContinue }
            $n++
        } catch {}
    }
    Move-Item -LiteralPath $Bak -Destination (Join-Path $Root ('usb_backup.restored.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.json')) -Force
    P ('   [OK] {0} values restored' -f $n) 'Green'
} else {
    $items = New-Object System.Collections.ArrayList
    $seen = @{}
    if (Test-Path -LiteralPath $Bak) {
        try {
            $old = Get-Content -LiteralPath $Bak -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($e in @($old.Items)) { if ($e) { [void]$items.Add($e); $seen[([string]$e.Path + '|' + [string]$e.Name).ToLower()] = $true } }
        } catch {}
    }
    $keys = Get-DevKeys
    $set = 0
    foreach ($k in $keys) {
        foreach ($nm in $names) {
            $cur = (Get-ItemProperty -LiteralPath $k -Name $nm -ErrorAction SilentlyContinue).$nm
            $id2 = ($k + '|' + $nm).ToLower()
            if ($null -ne $cur -and [int]$cur -eq 0) { continue }
            if (-not $seen.ContainsKey($id2)) {
                $seen[$id2] = $true
                $ex = ($null -ne $cur)
                $val = $null; if ($ex) { $val = [int]$cur }
                [void]$items.Add([pscustomobject]@{ Path = $k; Name = $nm; Exists = $ex; Value = $val })
            }
            try { New-ItemProperty -LiteralPath $k -Name $nm -Value 0 -PropertyType DWord -Force -ErrorAction Stop | Out-Null; $set++ } catch {}
        }
    }
    ([ordered]@{ Tool = 'USB'; Created = (Get-Date).ToString('o'); Items = $items } | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $Bak -Encoding UTF8
    P ('   [OK] {0} USB/HID devices scanned  ·  {1} values written' -f $keys.Count, $set) 'Green'
    P ('   Backup: ' + $Bak) 'DarkGray'
}

P ''
P '   Restart (or unplug / replug the mouse and keyboard) to apply.' 'Yellow'
if (-not $NoReboot) {
    P '   Restart now?  [Y] yes   [any other key] no' 'White'
    $a = Read-Host
    if ($a -match '^[Yy]') { shutdown.exe /r /t 5 /f /c 'BANNARAKX NETFORGE : USB/HID no-sleep' | Out-Null }
}
