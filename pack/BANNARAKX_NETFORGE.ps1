# ================================================================================
#  B A N N A R A K X   ::   N E T F O R G E   v1.0
#  Network Optimization Suite  -  DNS  .  Network Registry  .  Group Policy
#
#  - ไฟล์ใหม่ทั้งหมด ไม่แก้ไข / ไม่อ่าน / ไม่เขียนทับ ไฟล์ APEX เดิมและโฟลเดอร์ของมัน
#    (เก็บ Backup + Log แยกที่  C:\ProgramData\BannarakxNetForge)
#  - PowerShell 5.1+  /  Windows 10 - 11  /  ไม่มี exe  /  ไม่มี native interop
#  - ปรับ: DNS 1.1.1.1 + 1.0.0.1 · Network Registry · Group Policy (registry-backed)
#  - ทำงานจบแล้วรีสตาร์ทอัตโนมัติ (นับถอยหลัง 20 วินาที กด C เพื่อยกเลิก)
#  - มี Backup ค่าเดิม + เมนู Restore คืนค่าได้
#
#  วิธีรัน : คลิกขวา > Run with PowerShell  (ขอสิทธิ์ Administrator ให้เอง)
#  สวิตช์   : -Auto      ข้ามเมนู เริ่มทันที
#            -NoReboot  ไม่รีสตาร์ทเครื่องอัตโนมัติ
# ================================================================================
param(
    [switch]$Auto,
    [switch]$NoReboot
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

$Script:Brand   = 'BANNARAKX NETFORGE'
$Script:Ver     = '1.0.0'
$Script:Root    = Join-Path $env:ProgramData 'BannarakxNetForge'
$Script:BakFile = Join-Path $Script:Root 'backup.json'
$Script:BakTmp  = Join-Path $Script:Root 'backup.tmp'
$Script:LogFile = Join-Path $Script:Root ('netforge_{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
$Script:DnsPair = @('1.1.1.1', '1.0.0.1')
$Script:StepOk  = 0
$Script:StepSkip= 0
$Script:StepNo  = 0
$Script:StepNote= ''
$Script:RegDone = 0
$Script:Before  = $null
$Script:After   = $null
$Script:W       = 88

# ---------------------------------------------------------------- ADMIN
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host ''
    Write-Host '  [!] Administrator rights required - requesting...' -ForegroundColor Yellow
    if (-not $PSCommandPath) {
        Write-Host '  [X] Please save as a .ps1 file and run it from the file' -ForegroundColor Red
        Read-Host '  Press Enter to exit' | Out-Null
        exit 1
    }
    $argl = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath
    if ($Auto)     { $argl += ' -Auto' }
    if ($NoReboot) { $argl += ' -NoReboot' }
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argl -Verb RunAs | Out-Null
    } catch {
        Write-Host '  [X] Could not obtain Administrator rights' -ForegroundColor Red
        Read-Host '  Press Enter to exit' | Out-Null
    }
    exit
}

if ([Environment]::OSVersion.Version.Major -lt 10) {
    Write-Host ''
    Write-Host '  [X] Windows 10 / 11 or newer is required' -ForegroundColor Red
    Read-Host '  Press Enter to exit' | Out-Null
    exit 1
}

New-Item -ItemType Directory -Path $Script:Root -Force | Out-Null

# ---------------------------------------------------------------- CONSOLE
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try {
    $raw = $Host.UI.RawUI
    $raw.BackgroundColor = 'Black'
    $raw.ForegroundColor = 'Gray'
    $raw.WindowTitle = 'BANNARAKX NETFORGE  ::  Network Optimization Suite'
} catch {}
try { $raw = $Host.UI.RawUI; $b = $raw.BufferSize; if ($b.Width -lt 100) { $b.Width = 100; $raw.BufferSize = $b } } catch {}
try { $raw = $Host.UI.RawUI; $w = $raw.WindowSize; $w.Width = 100; $w.Height = [math]::Min(46, $raw.MaxPhysicalWindowSize.Height); $raw.WindowSize = $w } catch {}
try { $raw = $Host.UI.RawUI; $b = $raw.BufferSize; $b.Width = 100; $b.Height = 3000; $raw.BufferSize = $b } catch {}
try { $Script:W = [math]::Max(60, [math]::Min(88, $Host.UI.RawUI.WindowSize.Width - 6)) } catch {}

# ---------------------------------------------------------------- PALETTE
$Script:C = @{
    pink   = 'Magenta'
    violet = 'DarkMagenta'
    blue   = 'Blue'
    cyan   = 'Cyan'
    teal   = 'DarkCyan'
    lime   = 'Green'
    amber  = 'Yellow'
    red    = 'Red'
    white  = 'White'
    gray   = 'Gray'
    dim    = 'DarkGray'
    ink    = 'Black'
}

$Script:Art = @(
    '███╗   ██╗███████╗████████╗███████╗ ██████╗ ██████╗  ██████╗ ███████╗',
    '████╗  ██║██╔════╝╚══██╔══╝██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝',
    '██╔██╗ ██║█████╗     ██║   █████╗  ██║   ██║██████╔╝██║  ███╗█████╗  ',
    '██║╚██╗██║██╔══╝     ██║   ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  ',
    '██║ ╚████║███████╗   ██║   ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗',
    '╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝'
)

# ---------------------------------------------------------------- LOG
function Log {
    param([string]$M)
    try {
        Add-Content -LiteralPath $Script:LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $M) -Encoding UTF8
    } catch {}
}

# ---------------------------------------------------------------- UI PRIMITIVES
function Paint {
    param([string]$T, [string]$Fg = 'white', [string]$Bg = '', [switch]$NoNL)
    $a = @{ Object = $T; NoNewline = [bool]$NoNL; ForegroundColor = [string]$Script:C[$Fg] }
    if ($Bg) { $a['BackgroundColor'] = [string]$Script:C[$Bg] }
    Write-Host @a
}

function Chip {
    param([string]$T, [string]$Fg = 'ink', [string]$Bg = 'cyan', [switch]$NoNL)
    Paint (' ' + $T + ' ') $Fg $Bg -NoNL:$NoNL
}

function Cut {
    param([string]$S, [int]$N)
    $S = ($S -replace '[^\x20-\x7E\u00B7]', '?')
    if ($S.Length -gt $N) { return ($S.Substring(0, [math]::Max(0, $N - 1)) + '~') }
    return $S
}

function Show-ArtLine {
    param([string]$Line, [string[]]$Cols)
    $n   = $Line.Length
    $cur = 'Cyan'
    $sb  = New-Object System.Text.StringBuilder
    $blk = [char]0x2588
    for ($i = 0; $i -lt $n; $i++) {
        $ch = $Line[$i]
        if ($ch -eq $blk) {
            $idx = [math]::Min($Cols.Count - 1, [int][math]::Floor($i * $Cols.Count / $n))
            $col = $Cols[$idx]
        } elseif ($ch -eq ' ') {
            $col = $cur
        } else {
            $col = 'DarkGray'
        }
        if (($col -ne $cur) -and ($sb.Length -gt 0)) {
            Write-Host $sb.ToString() -NoNewline -ForegroundColor $cur
            [void]$sb.Clear()
        }
        $cur = $col
        [void]$sb.Append($ch)
    }
    if ($sb.Length -gt 0) { Write-Host $sb.ToString() -NoNewline -ForegroundColor $cur }
    Write-Host ''
}

function Show-Banner {
    try { Clear-Host } catch {}
    $cols = @('Magenta', 'Magenta', 'DarkMagenta', 'Blue', 'DarkCyan', 'Cyan', 'Cyan')
    Paint ''
    Paint '   ' -NoNL; Paint 'B A N N A R A K X' 'pink' -NoNL; Paint '   ·   ' 'dim' -NoNL; Paint 'P R E S E N T S' 'gray'
    Paint ''
    foreach ($l in $Script:Art) {
        Write-Host '   ' -NoNewline
        Show-ArtLine $l $cols
        Start-Sleep -Milliseconds 40
    }
    Paint ''
    Paint '   ' -NoNL; Paint 'NETWORK OPTIMIZATION SUITE' 'white' -NoNL; Paint ('   v' + $Script:Ver) 'dim'
    Paint ''
    Paint '   ' -NoNL
    Chip 'DNS' 'ink' 'cyan' -NoNL; Paint ' ' -NoNL
    Chip 'REGISTRY' 'ink' 'pink' -NoNL; Paint ' ' -NoNL
    Chip 'GROUP POLICY' 'ink' 'amber' -NoNL; Paint ' ' -NoNL
    Chip 'AUTO RESTART' 'ink' 'lime'
    Paint ''
}

function Box-Top {
    param([string]$T, [string]$Col = 'cyan')
    $inner = $Script:W - 2
    $head  = ' ' + $T + ' '
    Paint '  ╔═' $Col -NoNL
    Paint $head 'white' -NoNL
    Paint (('═' * [math]::Max(1, $inner - 1 - $head.Length)) + '╗') $Col
}

function Box-Row {
    param([string]$K, [string]$V, [string]$VCol = 'white', [string]$Col = 'cyan')
    $kw = 16
    $vw = ($Script:W - 2) - 2 - $kw
    $V  = Cut $V $vw
    Paint '  ║ ' $Col -NoNL
    Paint $K.PadRight($kw) 'gray' -NoNL
    Paint $V.PadRight($vw) $VCol -NoNL
    Paint ' ║' $Col
}

function Box-Sep {
    param([string]$Col = 'cyan')
    Paint ('  ╟' + ('─' * ($Script:W - 2)) + '╢') $Col
}

function Box-Bottom {
    param([string]$Col = 'cyan')
    Paint ('  ╚' + ('═' * ($Script:W - 2)) + '╝') $Col
}

function Sector {
    param([string]$No, [string]$Title, [string]$Sub = '', [string]$Col = 'cyan')
    $head = ('PHASE {0}  {1}' -f $No, $Title)
    Paint ''
    Paint '  ■ ' $Col -NoNL
    Paint $head 'white' -NoNL
    Paint ' ' -NoNL
    Paint ('─' * [math]::Max(4, $Script:W - 5 - $head.Length)) 'dim'
    if ($Sub) { Paint ('    ' + $Sub) 'gray' }
    Paint ''
    Log ('PHASE ' + $head)
}

function Say {
    param([string]$T, [string]$Kind = 'info')
    switch ($Kind) {
        'ok'    { Paint '   √ ' 'lime'  -NoNL; Paint $T 'white' }
        'warn'  { Paint '   ▲ ' 'amber' -NoNL; Paint $T 'amber' }
        'bad'   { Paint '   × ' 'red'   -NoNL; Paint $T 'red' }
        'dim'   { Paint ('     ' + $T) 'dim' }
        default { Paint '   ♦ ' 'cyan'  -NoNL; Paint $T 'gray' }
    }
    Log $T
}

function Step {
    param([string]$Title, [scriptblock]$Do)
    $Script:StepNo++
    $tag = '{0:00}' -f $Script:StepNo
    Paint ('   {0} ' -f $tag) 'dim' -NoNL
    Paint '[ .... ] ' 'amber' -NoNL
    Paint $Title 'gray' -NoNL
    $ok = $true
    $Script:StepNote = ''
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $r = @(& $Do)
        if ($r.Count -gt 0 -and $r[$r.Count - 1] -is [bool]) { $ok = $r[$r.Count - 1] }
    } catch {
        $ok = $false
        Log ('STEP FAIL: {0} :: {1}' -f $Title, $_.Exception.Message)
    }
    $sw.Stop()
    Write-Host "`r" -NoNewline
    Paint ('   {0} ' -f $tag) 'dim' -NoNL
    if ($ok) {
        Paint '[  OK  ] ' 'lime' -NoNL
        Paint $Title 'white' -NoNL
        $Script:StepOk++
    } else {
        Paint '[ SKIP ] ' 'amber' -NoNL
        Paint $Title 'gray' -NoNL
        $Script:StepSkip++
    }
    Paint ('  {0} ms' -f [int]$sw.Elapsed.TotalMilliseconds) 'dim'
    if ($Script:StepNote) { Paint ('            └ ' + $Script:StepNote) 'gray' }
    Log ('{0} => {1}' -f $Title, $ok)
}

function Bar {
    param([int]$Pct, [string]$Label = '')
    $w = 40
    $f = [int][math]::Floor($w * $Pct / 100)
    Paint ''
    Paint '   ' -NoNL
    Paint ('█' * $f) 'cyan' -NoNL
    Paint ('░' * ($w - $f)) 'dim' -NoNL
    Paint ('  {0,3}%  {1}' -f $Pct, $Label) 'gray'
}

# ================================================================================
#  BACKUP  -  เก็บค่าเดิมครั้งแรกไว้เสมอ (ไม่ถูกเขียนทับเมื่อรันซ้ำ) แยกจากไฟล์เดิม
# ================================================================================
$Script:B = [ordered]@{
    Tool    = 'NETFORGE'
    Version = $Script:Ver
    Created = (Get-Date).ToString('o')
    Computer= $env:COMPUTERNAME
    Reg     = (New-Object System.Collections.ArrayList)
    Dns     = (New-Object System.Collections.ArrayList)
    Tcp     = $null
}
$Script:Seen  = @{}
$Script:Dirty = $false

function Key-Reg {
    param([string]$Path, [string]$Name)
    return ('R|' + $Path.ToLowerInvariant() + '|' + $Name.ToLowerInvariant())
}

function Load-Backup {
    if (-not (Test-Path -LiteralPath $Script:BakFile)) { return $false }
    try {
        $d = Get-Content -LiteralPath $Script:BakFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($d.Tool -ne 'NETFORGE') { throw 'not a NETFORGE backup' }
        foreach ($r in @($d.Reg)) {
            if ($r) { [void]$Script:B['Reg'].Add($r); $Script:Seen[(Key-Reg $r.Path $r.Name)] = $true }
        }
        foreach ($r in @($d.Dns)) {
            if ($r) { [void]$Script:B['Dns'].Add($r); $Script:Seen[('D|' + ([string]$r.Guid).ToLowerInvariant())] = $true }
        }
        if ($d.Tcp)     { $Script:B['Tcp'] = $d.Tcp; $Script:Seen['TCP'] = $true }
        if ($d.Created) { $Script:B['Created'] = $d.Created }
        return $true
    } catch {
        Log ('Backup load failed: ' + $_.Exception.Message)
        try { Rename-Item -LiteralPath $Script:BakFile -NewName ('backup.bad.' + (Get-Date -Format 'yyyyMMddHHmmss')) -Force } catch {}
        return $false
    }
}

function Save-Backup {
    if ((-not $Script:Dirty) -and (Test-Path -LiteralPath $Script:BakFile)) { return $true }
    try {
        $json = $Script:B | ConvertTo-Json -Depth 6
        Set-Content -LiteralPath $Script:BakTmp -Value $json -Encoding UTF8
        $test = Get-Content -LiteralPath $Script:BakTmp -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($test.Tool -ne 'NETFORGE') { throw 'validate failed' }
        Move-Item -LiteralPath $Script:BakTmp -Destination $Script:BakFile -Force
        $Script:Dirty = $false
        return $true
    } catch {
        Log ('Backup save failed: ' + $_.Exception.Message)
        return $false
    }
}

function Get-RegState {
    param([string]$Path, [string]$Name)
    $o = [pscustomobject]@{ Path = $Path; Name = $Name; Exists = $false; Value = $null; Kind = $null }
    try {
        if (Test-Path -LiteralPath $Path) {
            $k = Get-Item -LiteralPath $Path
            if ($k.GetValueNames() -contains $Name) {
                $o.Exists = $true
                $o.Value  = $k.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $o.Kind   = $k.GetValueKind($Name).ToString()
            }
        }
    } catch {}
    return $o
}

function Note-Reg {
    param([string]$Path, [string]$Name)
    $k = Key-Reg $Path $Name
    if ($Script:Seen.ContainsKey($k)) { return }
    $Script:Seen[$k] = $true
    [void]$Script:B['Reg'].Add((Get-RegState $Path $Name))
    $Script:Dirty = $true
}

function Note-Dns {
    param($Nic)
    $guid = ([string]$Nic.InterfaceGuid).ToLowerInvariant()
    $k = 'D|' + $guid
    if ($Script:Seen.ContainsKey($k)) { return }
    $Script:Seen[$k] = $true
    $static = $false; $servers = @()
    $ip = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\' + [string]$Nic.InterfaceGuid
    $ns = (Get-ItemProperty -LiteralPath $ip -Name NameServer -ErrorAction SilentlyContinue).NameServer
    if ($ns) { $static = $true; $servers = @(($ns -split '[ ,]+') | Where-Object { $_ }) }
    [void]$Script:B['Dns'].Add([pscustomobject]@{ Guid = [string]$Nic.InterfaceGuid; Name = [string]$Nic.Name; Static = $static; Servers = $servers })
    $Script:Dirty = $true
}

function Note-Tcp {
    if ($Script:Seen.ContainsKey('TCP')) { return }
    $t = Get-NetTCPSetting -SettingName InternetCustom -ErrorAction SilentlyContinue
    if (-not $t) { $t = Get-NetTCPSetting -ErrorAction SilentlyContinue | Where-Object { $_.SettingName -like 'Internet*' } | Select-Object -First 1 }
    $o = Get-NetOffloadGlobalSetting -ErrorAction SilentlyContinue
    if ((-not $t) -and (-not $o)) { return }
    $Script:Seen['TCP'] = $true
    $Script:B['Tcp'] = [pscustomobject]@{
        Auto = [string]$t.AutoTuningLocalLevel
        Ecn  = [string]$t.EcnCapability
        Ts   = [string]$t.Timestamps
        Rss  = [string]$o.ReceiveSideScaling
        Rsc  = [string]$o.ReceiveSegmentCoalescing
    }
    $Script:Dirty = $true
}

function Commit {
    if (-not (Save-Backup)) { Say 'Backup could not be saved (check ProgramData folder permissions)' 'warn' }
}

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    try {
        Note-Reg $Path $Name
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        $Script:RegDone++
        return $true
    } catch {
        Log ('REG FAIL ' + $Path + '\' + $Name + ' :: ' + $_.Exception.Message)
        return $false
    }
}

function Set-RegBatch {
    param($Items)
    $ok = 0
    foreach ($i in $Items) {
        if (Set-Reg $i[0] $i[1] $i[2] $i[3]) { $ok++ }
    }
    return $ok
}

# ---------------------------------------------------------------- PLANS  (ทุกค่าที่จะเขียน)
function New-Plan { return ,(New-Object System.Collections.ArrayList) }
function Add-Plan {
    param($Plan, [string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    [void]$Plan.Add(@($Path, $Name, $Value, $Type))
}

function Plan-Nagle {
    $p = New-Plan
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    foreach ($i in @(Get-ChildItem -LiteralPath $base -ErrorAction SilentlyContinue)) {
        $v = Get-ItemProperty -LiteralPath $i.PSPath -ErrorAction SilentlyContinue
        if ($v -and ($v.DhcpIPAddress -or $v.IPAddress)) {
            $path = $base + '\' + $i.PSChildName
            Add-Plan $p $path 'TcpAckFrequency' 1
            Add-Plan $p $path 'TCPNoDelay' 1
            Add-Plan $p $path 'TcpDelAckTicks' 0
        }
    }
    return ,$p
}

function Plan-Throttle {
    $p = New-Plan
    Add-Plan $p 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xFFFFFFFF
    return ,$p
}

function Plan-TcpIp {
    $p = New-Plan
    $t = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    Add-Plan $p $t 'TcpTimedWaitDelay' 30
    Add-Plan $p $t 'MaxUserPort' 65534
    Add-Plan $p $t 'EnablePMTUDiscovery' 1
    return ,$p
}

function Plan-DnsCache {
    $p = New-Plan
    $d = 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters'
    Add-Plan $p $d 'NegativeSOACacheTime' 0
    Add-Plan $p $d 'NetFailureCacheTime' 0
    return ,$p
}

function Plan-PolDns {
    $p = New-Plan
    $d = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
    Add-Plan $p $d 'EnableMulticast' 0
    Add-Plan $p $d 'DisableSmartNameResolution' 1
    return ,$p
}

function Plan-PolQos {
    $p = New-Plan
    Add-Plan $p 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched' 'NonBestEffortLimit' 0
    return ,$p
}

function Plan-PolDelivery {
    $p = New-Plan
    $d = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
    Add-Plan $p $d 'DODownloadMode' 0
    Add-Plan $p $d 'DOPercentageMaxBackgroundBandwidth' 20
    Add-Plan $p $d 'DOPercentageMaxForegroundBandwidth' 50
    return ,$p
}

function Plan-PolUpdate {
    $p = New-Plan
    Add-Plan $p 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1
    Add-Plan $p 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 2
    return ,$p
}

function Plan-PolPeer {
    $p = New-Plan
    Add-Plan $p 'HKLM:\SOFTWARE\Policies\Microsoft\Peernet' 'Disabled' 1
    Add-Plan $p 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config' 'AutoConnectAllowedOEM' 0
    return ,$p
}

# ================================================================================
#  SYSTEM PROBES
# ================================================================================
function Get-TargetNics {
    $bad = 'Virtual|Loopback|VPN|TAP|Hyper-V|VMware|vEthernet|Bluetooth|Tunnel|Pseudo|Wintun|WireGuard'
    $l = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Bluetooth' })
    if ($l.Count -eq 0) {
        $l = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch $bad })
    }
    return $l
}

function Get-NicKind {
    param($Nic)
    if (-not $Nic) { return 'N/A' }
    if ($Nic.NdisPhysicalMedium -eq 9 -or ([string]$Nic.PhysicalMediaType) -match '802\.11' -or $Nic.InterfaceDescription -match 'Wi-?Fi|Wireless|WLAN|802\.11') { return 'WIFI' }
    return 'LAN'
}

function Get-SysInfo {
    $s = @{}
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $s.Os  = ((([string]$os.Caption) -replace 'Microsoft ', '').Trim() + '  (build ' + [string]$os.BuildNumber + ')')
    $s.Cpu = (([string]$cpu.Name) -replace '\s+', ' ').Trim()
    $s.Ram = ('{0} GB' -f [math]::Round($os.TotalVisibleMemorySize / 1MB, 1))
    return $s
}

function Measure-Ping {
    param([string]$Target, [int]$Count = 8, [int]$Timeout = 1000)
    $png = New-Object System.Net.NetworkInformation.Ping
    $rtt = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $Count; $i++) {
        try {
            $r = $png.Send($Target, $Timeout)
            if ($r.Status -eq 'Success') { [void]$rtt.Add([double]$r.RoundtripTime) }
        } catch {}
        Start-Sleep -Milliseconds 120
    }
    $o = [pscustomobject]@{ Sent = $Count; Recv = $rtt.Count; Loss = 100.0; Avg = 0; Jitter = 0 }
    if ($rtt.Count -gt 0) {
        $o.Loss = [math]::Round(100.0 * ($Count - $rtt.Count) / $Count, 1)
        $o.Avg  = [math]::Round(($rtt | Measure-Object -Average).Average, 1)
        $j = 0.0
        for ($i = 1; $i -lt $rtt.Count; $i++) { $j += [math]::Abs($rtt[$i] - $rtt[$i - 1]) }
        if ($rtt.Count -gt 1) { $o.Jitter = [math]::Round($j / ($rtt.Count - 1), 1) }
    }
    return $o
}

function Measure-DnsLookup {
    param([string]$Server = '')
    $sum = 0.0; $ok = 0
    foreach ($n in @('cloudflare.com', 'microsoft.com', 'google.com', 'wikipedia.org', 'github.com')) {
        try {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            if ($Server) { Resolve-DnsName -Name $n -Server $Server -Type A -DnsOnly -NoHostsFile -ErrorAction Stop | Out-Null }
            else         { Resolve-DnsName -Name $n -Type A -DnsOnly -NoHostsFile -ErrorAction Stop | Out-Null }
            $sw.Stop()
            $sum += $sw.Elapsed.TotalMilliseconds
            $ok++
        } catch {}
    }
    if ($ok -eq 0) { return -1 }
    return [int][math]::Round($sum / $ok, 0)
}

function Fmt-Ms {
    param($V)
    if ($V -lt 0) { return 'timeout' }
    return ('{0} ms' -f $V)
}

function Get-NetSnapshot {
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    $d = Measure-DnsLookup
    $p = Measure-Ping '1.1.1.1' 6
    return [pscustomobject]@{ Dns = $d; Ping = $p }
}

# ================================================================================
#  HUD
# ================================================================================
function Show-Hud {
    $s = Get-SysInfo
    $nics = @(Get-TargetNics)
    Box-Top 'SYSTEM SCAN'
    Box-Row 'OS'  $s.Os
    Box-Row 'CPU' $s.Cpu
    Box-Row 'RAM' $s.Ram
    Box-Sep 'dim'
    if ($nics.Count -eq 0) {
        Box-Row 'ADAPTER' 'No active network adapter detected' 'amber'
    } else {
        $n = 0
        foreach ($nic in ($nics | Select-Object -First 3)) {
            $n++
            Box-Row ('ADAPTER ' + $n) ('{0}  [{1} · {2}]' -f (Cut $nic.InterfaceDescription 44), (Get-NicKind $nic), [string]$nic.LinkSpeed) 'cyan'
        }
        $cur = @((Get-DnsClientServerAddress -InterfaceIndex $nics[0].ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
        $curTxt = 'automatic (DHCP)'
        if ($cur.Count -gt 0) { $curTxt = ($cur -join ' / ') }
        Box-Row 'DNS NOW' $curTxt 'white'
    }
    Box-Row 'DNS TARGET' ($Script:DnsPair -join ' / ') 'lime'
    Box-Sep 'dim'
    if (Test-Path -LiteralPath $Script:BakFile) {
        Box-Row 'BACKUP' 'found - your original values are preserved' 'lime'
    } else {
        Box-Row 'BACKUP' 'will be created automatically before any change' 'amber'
    }
    Box-Bottom
}

function Ask-Menu {
    Paint ''
    Paint '   ' -NoNL; Chip 'ENTER' 'ink' 'lime' -NoNL; Paint '  START full optimization, then auto-restart' 'white'
    Paint '   ' -NoNL; Chip '  R  ' 'ink' 'amber' -NoNL; Paint '  RESTORE original values' 'gray'
    Paint '   ' -NoNL; Chip '  Q  ' 'ink' 'red' -NoNL; Paint '  QUIT' 'gray'
    Paint ''
    Paint '   ► ' 'cyan' -NoNL
    $a = Read-Host
    if ($a -match '^[Rr]') { return 'R' }
    if ($a -match '^[Qq]') { return 'Q' }
    return 'S'
}

# ================================================================================
#  REBOOT
# ================================================================================
function Start-Countdown {
    param([int]$Sec = 20, [string]$Msg = 'Optimization complete - restarting automatically so every change takes full effect')
    Paint ''
    Paint ('  ' + ('═' * $Script:W)) 'amber'
    Paint '   ► ' 'amber' -NoNL; Paint $Msg 'white'
    Paint '     Save your open work first  ·  press ' 'gray' -NoNL; Chip 'C' 'ink' 'red' -NoNL; Paint ' to cancel' 'gray'
    Paint ''
    for ($i = $Sec; $i -ge 1; $i--) {
        $w = 30
        $f = [int][math]::Round($w * $i / $Sec)
        Write-Host "`r" -NoNewline
        Paint '   RESTART IN ' 'amber' -NoNL
        Paint ('{0,2}s  ' -f $i) 'white' -NoNL
        Paint ('█' * $f) 'amber' -NoNL
        Paint ('░' * ($w - $f)) 'dim' -NoNL
        Paint '   ' -NoNL
        for ($t = 0; $t -lt 10; $t++) {
            Start-Sleep -Milliseconds 100
            try {
                if ([Console]::KeyAvailable) {
                    $k = [Console]::ReadKey($true)
                    if ($k.Key -eq [ConsoleKey]::C) {
                        Paint ''
                        Paint ''
                        Say 'Restart cancelled - changes take full effect after you restart manually' 'warn'
                        return $false
                    }
                }
            } catch {}
        }
    }
    Paint ''
    Paint ''
    Say 'Restarting...' 'ok'
    Log 'AUTO RESTART'
    shutdown.exe /r /t 3 /f /c 'BANNARAKX NETFORGE : restarting to apply network optimizations' | Out-Null
    Start-Sleep -Seconds 6
    return $true
}

# ================================================================================
#  MAIN TUNE
# ================================================================================
function Start-Forge {
    $Script:StepOk = 0; $Script:StepSkip = 0; $Script:StepNo = 0; $Script:RegDone = 0
    $t0 = Get-Date

    # ------------------------------------------------------------ PHASE 0
    Sector '0/4' 'PREPARE' 'Restore point · safety backup · baseline measurement' 'violet'

    Step 'Create Windows restore point' {
        try {
            Checkpoint-Computer -Description 'BANNARAKX NETFORGE' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop | Out-Null
            return $true
        } catch {
            $Script:StepNote = 'System Protection is off or limited to 1 point / 24h - skipped'
            return $false
        }
    }

    Step 'Safety backup · registry · DNS · TCP (original values)' {
        foreach ($nic in @(Get-TargetNics)) { Note-Dns $nic }
        Note-Tcp
        $plans = @((Plan-Nagle), (Plan-Throttle), (Plan-TcpIp), (Plan-DnsCache), (Plan-PolDns), (Plan-PolQos), (Plan-PolDelivery), (Plan-PolUpdate), (Plan-PolPeer))
        foreach ($pl in $plans) { foreach ($it in $pl) { Note-Reg $it[0] $it[1] } }
        Commit
        $Script:StepNote = ('{0} registry values saved  ->  {1}' -f $Script:B['Reg'].Count, $Script:BakFile)
        return (Test-Path -LiteralPath $Script:BakFile)
    }

    Step 'Baseline snapshot · ping + DNS lookup (before)' {
        $Script:Before = Get-NetSnapshot
        $Script:StepNote = ('Ping 1.1.1.1 = {0} ms  ·  Loss {1}%  ·  DNS lookup = {2}' -f $Script:Before.Ping.Avg, $Script:Before.Ping.Loss, (Fmt-Ms $Script:Before.Dns))
        return $true
    }
    Bar 15 'PREPARE'

    # ------------------------------------------------------------ PHASE 1
    Sector '1/4' 'DNS ENGINE' 'Cloudflare 1.1.1.1 / 1.0.0.1  ·  every active adapter' 'cyan'

    Step 'Set DNS = 1.1.1.1 / 1.0.0.1' {
        $nics = @(Get-TargetNics)
        if ($nics.Count -eq 0) { $Script:StepNote = 'No active network adapter found'; return $false }
        $n = 0
        foreach ($nic in $nics) {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $Script:DnsPair -ErrorAction Stop
                $n++
            } catch { Log ('DNS FAIL ' + $nic.Name + ' :: ' + $_.Exception.Message) }
        }
        $Script:StepNote = ('{0} adapter(s): {1}' -f $n, ((@($nics | ForEach-Object { Cut $_.InterfaceDescription 36 })) -join ' | '))
        return ($n -gt 0)
    }

    Step 'DNS cache tuning · negative / failure caching' {
        $n = Set-RegBatch (Plan-DnsCache)
        return ($n -gt 0)
    }

    Step 'Flush DNS resolver cache' {
        ipconfig /flushdns 2>$null | Out-Null
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        return $true
    }
    Commit
    Bar 35 'DNS ENGINE'

    # ------------------------------------------------------------ PHASE 2
    Sector '2/4' 'NETWORK REGISTRY' 'Latency · throttling · TCP/IP stack' 'pink'

    Step 'Nagle OFF · TcpAckFrequency / TCPNoDelay (per interface)' {
        $plan = Plan-Nagle
        $n = Set-RegBatch $plan
        $Script:StepNote = ('{0} values on {1} interface(s)' -f $n, [int]($plan.Count / 3))
        return ($n -gt 0)
    }

    Step 'Network throttling index · disabled' {
        $n = Set-RegBatch (Plan-Throttle)
        return ($n -gt 0)
    }

    Step 'TCP/IP · TIME_WAIT 30s · 65534 ports · PMTU discovery' {
        $n = Set-RegBatch (Plan-TcpIp)
        return ($n -gt 0)
    }

    Step 'TCP stack · autotune normal · RSS on · RSC/ECN/TS off' {
        netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
        netsh int tcp set global rss=enabled 2>$null | Out-Null
        netsh int tcp set global ecncapability=disabled 2>$null | Out-Null
        netsh int tcp set global timestamps=disabled 2>$null | Out-Null
        try { Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Disabled -ErrorAction Stop } catch { netsh int tcp set global rsc=disabled 2>$null | Out-Null }
        return $true
    }
    Commit
    Bar 60 'NETWORK REGISTRY'

    # ------------------------------------------------------------ PHASE 3
    Sector '3/4' 'GROUP POLICY' 'Registry-backed policies · works on Windows Home and Pro' 'amber'

    Step 'DNS Client policy · LLMNR off · smart name resolution off' {
        $n = Set-RegBatch (Plan-PolDns)
        return ($n -gt 0)
    }

    Step 'QoS Packet Scheduler · reserved bandwidth = 0%' {
        $n = Set-RegBatch (Plan-PolQos)
        return ($n -gt 0)
    }

    Step 'Delivery Optimization · P2P off · update bandwidth cap' {
        $n = Set-RegBatch (Plan-PolDelivery)
        $Script:StepNote = 'Windows Update background 20% / foreground 50% of your line'
        return ($n -gt 0)
    }

    Step 'Windows Update / Store · no surprise reboot · no auto-DL' {
        $n = Set-RegBatch (Plan-PolUpdate)
        return ($n -gt 0)
    }

    Step 'Peer networking off · Wi-Fi Sense off' {
        $n = Set-RegBatch (Plan-PolPeer)
        return ($n -gt 0)
    }

    Step 'Apply policies (gpupdate)' {
        gpupdate /force /wait:0 2>$null | Out-Null
        return $true
    }
    Commit
    Bar 85 'GROUP POLICY'

    # ------------------------------------------------------------ PHASE 4
    Sector '4/4' 'VERIFY' 'Confirm DNS · refresh caches · measure again' 'lime'

    Step 'Refresh network caches · DNS / ARP / NetBIOS' {
        ipconfig /flushdns 2>$null | Out-Null
        netsh int ip delete arpcache 2>$null | Out-Null
        nbtstat -R 2>$null | Out-Null
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        return $true
    }

    Step 'Verify resolver on every adapter' {
        $ok = $true
        foreach ($nic in @(Get-TargetNics)) {
            $cur = @((Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
            if (($cur -notcontains '1.1.1.1') -or ($cur -notcontains '1.0.0.1')) { $ok = $false }
        }
        $a = Measure-DnsLookup '1.1.1.1'
        $b = Measure-DnsLookup '1.0.0.1'
        $Script:StepNote = ('1.1.1.1 = {0}  ·  1.0.0.1 = {1}' -f (Fmt-Ms $a), (Fmt-Ms $b))
        return $ok
    }

    Step 'Result snapshot · ping + DNS lookup (after)' {
        $Script:After = Get-NetSnapshot
        $Script:StepNote = ('Ping 1.1.1.1 = {0} ms  ·  Loss {1}%  ·  DNS lookup = {2}' -f $Script:After.Ping.Avg, $Script:After.Ping.Loss, (Fmt-Ms $Script:After.Dns))
        return $true
    }
    Commit
    Bar 100 'COMPLETE'

    # ------------------------------------------------------------ RESULT
    $dur = [int]((Get-Date) - $t0).TotalSeconds
    Paint ''
    Box-Top 'RESULT' 'lime'
    Box-Row 'STEPS'       ('{0} OK  ·  {1} skipped  ·  {2} registry values written' -f $Script:StepOk, $Script:StepSkip, $Script:RegDone) 'white' 'lime'
    Box-Row 'DNS'         ($Script:DnsPair -join ' / ') 'lime' 'lime'
    if ($Script:Before -and $Script:After) {
        $dCol = 'white'
        if ($Script:After.Dns -ge 0 -and $Script:Before.Dns -ge 0) { if ($Script:After.Dns -le $Script:Before.Dns) { $dCol = 'lime' } else { $dCol = 'amber' } }
        $pCol = 'white'
        if ($Script:After.Ping.Recv -gt 0 -and $Script:Before.Ping.Recv -gt 0) { if ($Script:After.Ping.Avg -le $Script:Before.Ping.Avg) { $pCol = 'lime' } else { $pCol = 'amber' } }
        Box-Row 'DNS LOOKUP'  ('{0}  ->  {1}' -f (Fmt-Ms $Script:Before.Dns), (Fmt-Ms $Script:After.Dns)) $dCol 'lime'
        Box-Row 'PING 1.1.1.1' ('{0} ms  ->  {1} ms' -f $Script:Before.Ping.Avg, $Script:After.Ping.Avg) $pCol 'lime'
        Box-Row 'JITTER'      ('{0} ms  ->  {1} ms' -f $Script:Before.Ping.Jitter, $Script:After.Ping.Jitter) 'white' 'lime'
        Box-Row 'PACKET LOSS' ('{0}%  ->  {1}%' -f $Script:Before.Ping.Loss, $Script:After.Ping.Loss) 'white' 'lime'
    }
    Box-Row 'TIME'        ('{0} seconds' -f $dur) 'white' 'lime'
    Box-Row 'BACKUP'      $Script:BakFile 'gray' 'lime'
    Box-Bottom 'lime'
    Paint ''
    Say 'Everything takes full effect after the restart (numbers above were measured before it)' 'dim'

    if ($NoReboot) {
        Say 'Auto-restart disabled (-NoReboot) - please restart manually' 'warn'
        return $false
    }
    return (Start-Countdown 20)
}

# ================================================================================
#  RESTORE
# ================================================================================
function Restore-RegItem {
    param($R)
    try {
        if ($R.Exists) {
            if (-not (Test-Path -LiteralPath $R.Path)) { New-Item -Path $R.Path -Force | Out-Null }
            $kind = [string]$R.Kind
            if (-not $kind) { $kind = 'DWord' }
            $val = $R.Value
            if ($kind -eq 'DWord') { $val = [int]$val }
            New-ItemProperty -LiteralPath $R.Path -Name $R.Name -Value $val -PropertyType $kind -Force -ErrorAction Stop | Out-Null
        } else {
            if (Test-Path -LiteralPath $R.Path) {
                Remove-ItemProperty -LiteralPath $R.Path -Name $R.Name -Force -ErrorAction SilentlyContinue
            }
        }
        return $true
    } catch {
        Log ('RESTORE FAIL ' + $R.Path + '\' + $R.Name + ' :: ' + $_.Exception.Message)
        return $false
    }
}

function Invoke-Restore {
    $Script:StepOk = 0; $Script:StepSkip = 0; $Script:StepNo = 0
    if (-not (Test-Path -LiteralPath $Script:BakFile)) {
        Paint ''
        Say 'No backup found - NETFORGE has not been run yet, or it was already restored' 'warn'
        return $false
    }
    $d = $null
    try { $d = Get-Content -LiteralPath $Script:BakFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    if ((-not $d) -or ($d.Tool -ne 'NETFORGE')) {
        Paint ''
        Say 'Backup file is damaged or unreadable' 'bad'
        return $false
    }

    Sector 'R' 'RESTORE' 'Return every value to what it was before NETFORGE' 'amber'

    Step 'Registry values' {
        $ok = 0; $all = 0
        foreach ($r in @($d.Reg)) {
            if (-not $r) { continue }
            $all++
            if (Restore-RegItem $r) { $ok++ }
        }
        $Script:StepNote = ('{0} / {1} values restored' -f $ok, $all)
        return ($ok -eq $all)
    }

    Step 'DNS servers per adapter' {
        $ok = 0; $all = 0
        foreach ($r in @($d.Dns)) {
            if (-not $r) { continue }
            $all++
            $a = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { [string]$_.InterfaceGuid -ieq [string]$r.Guid } | Select-Object -First 1
            if (-not $a) { continue }
            try {
                if ($r.Static) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses @($r.Servers) -ErrorAction Stop }
                else           { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop }
                $ok++
            } catch { Log ('DNS RESTORE FAIL ' + $r.Name + ' :: ' + $_.Exception.Message) }
        }
        ipconfig /flushdns 2>$null | Out-Null
        $Script:StepNote = ('{0} / {1} adapters restored' -f $ok, $all)
        return ($all -gt 0 -and $ok -gt 0)
    }

    Step 'TCP stack settings' {
        $t = $d.Tcp
        if (-not $t) { return $false }
        $auto = ([string]$t.Auto).ToLower(); $ecn = ([string]$t.Ecn).ToLower(); $ts = ([string]$t.Ts).ToLower(); $rss = ([string]$t.Rss).ToLower(); $rsc = ([string]$t.Rsc)
        if ($auto -match '^[a-z]+$') { netsh int tcp set global autotuninglevel=$auto 2>$null | Out-Null }
        if ($ecn  -match '^[a-z]+$') { netsh int tcp set global ecncapability=$ecn 2>$null | Out-Null }
        if ($ts   -match '^[a-z]+$') { netsh int tcp set global timestamps=$ts 2>$null | Out-Null }
        if ($rss  -match '^[a-z]+$') { netsh int tcp set global rss=$rss 2>$null | Out-Null }
        if ($rsc -match '^(Enabled|Disabled)$') { try { Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing $rsc -ErrorAction Stop } catch {} }
        return $true
    }

    Step 'Apply policies (gpupdate)' {
        gpupdate /force /wait:0 2>$null | Out-Null
        return $true
    }

    try { Move-Item -LiteralPath $Script:BakFile -Destination (Join-Path $Script:Root ('backup.restored.' + (Get-Date -Format 'yyyyMMddHHmmss') + '.json')) -Force } catch {}

    Paint ''
    Box-Top 'RESTORED' 'amber'
    Box-Row 'STEPS' ('{0} OK  ·  {1} skipped' -f $Script:StepOk, $Script:StepSkip) 'white' 'amber'
    Box-Row 'NOTE' 'Backup archived - next run will record fresh originals' 'gray' 'amber'
    Box-Bottom 'amber'

    if ($NoReboot) {
        Say 'Auto-restart disabled (-NoReboot) - please restart manually' 'warn'
        return $false
    }
    return (Start-Countdown 15 'Restore complete - restarting automatically so the values take effect')
}

# ================================================================================
#  START
# ================================================================================
Show-Banner
[void](Load-Backup)
Show-Hud

$choice = 'S'
if (-not $Auto) { $choice = Ask-Menu }

$rebooted = $false
switch ($choice) {
    'S' { $rebooted = Start-Forge }
    'R' { $rebooted = Invoke-Restore }
    default { }
}

if ($rebooted) { exit }

Paint ''
if ($choice -eq 'Q') {
    Say 'Thank you for using BANNARAKX NETFORGE' 'dim'
} else {
    Paint '   ' -NoNL; Chip 'ENTER' 'ink' 'dim' -NoNL; Paint ' CLOSE' 'dim'
    Read-Host | Out-Null
}
