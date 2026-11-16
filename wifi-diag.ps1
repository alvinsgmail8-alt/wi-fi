#Requires -Version 5.1
<#
.SYNOPSIS
  Wi-Fi diagnostikasi va optimallashtirish: OLDIN o'lchov -> tahlil -> (ruxsat bilan) tuzatish -> KEYIN o'lchov -> taqqoslash.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\wifi-diag.ps1                 # hamma bosqich ketma-ket
  powershell -ExecutionPolicy Bypass -File .\wifi-diag.ps1 -Step Before    # faqat OLDIN o'lchov
  powershell -ExecutionPolicy Bypass -File .\wifi-diag.ps1 -Step Analyze
  powershell -ExecutionPolicy Bypass -File .\wifi-diag.ps1 -Step Fix       # Administrator kerak
  powershell -ExecutionPolicy Bypass -File .\wifi-diag.ps1 -Step After
  powershell -ExecutionPolicy Bypass -File .\wifi-diag.ps1 -Step Compare
  powershell -ExecutionPolicy Bypass -File .\wifi-diag.ps1 -Step Restore   # zaxiradan qaytarish
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Before', 'Analyze', 'Fix', 'After', 'Compare', 'Restore')]
    [string]$Step = 'All',
    [ValidateRange(1, 120)]
    [int]$Minutes = 12,
    [string]$Target = '8.8.8.8',
    [int]$SpikeMs = 30,
    [string]$OutDir = (Join-Path $PSScriptRoot 'natijalar'),
    [string]$BackupFile
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

# ----------------------------------------------------------------- yordamchilar
function Say([string]$t, [string]$c = 'Gray') { Write-Host $t -ForegroundColor $c }
function Head([string]$t) { Write-Host ''; Write-Host ('=== ' + $t + ' ===') -ForegroundColor Cyan }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ask([string]$q) {
    while ($true) {
        $a = (Read-Host "$q [ha/yo'q]").Trim().ToLower()
        if ($a -match '^(h|ha|да|д)$') { return $true }
        if ($a -match "^(y|yoq|yo'q|n|no|нет|н)$") { return $false }
        Say "  'ha' yoki 'yo'q' deb yozing." Yellow
    }
}

function Save-Json($obj, [string]$path) {
    $obj | ConvertTo-Json -Depth 8 | Set-Content -Path $path -Encoding UTF8
    Say "  Saqlandi: $path" DarkGray
}

function Get-Latest([string]$pattern) {
    Get-ChildItem -Path $OutDir -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Get-BandFromChannel($ch) {
    if (-not $ch) { return $null }
    if ($ch -ge 1 -and $ch -le 14) { return '2.4 GHz' }
    if ($ch -ge 32 -and $ch -le 177) { return '5 GHz' }
    return $null
}

# ----------------------------------------------------------------- Wi-Fi ma'lumotlari
function Get-WifiAdapter {
    $all = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.NdisPhysicalMedium -eq 9 })
    $a = $all | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    if (-not $a) { $a = $all | Select-Object -First 1 }
    if (-not $a) { throw 'Wi-Fi adapter topilmadi.' }
    $a
}

function Get-NetshPairs([string[]]$lines) {
    foreach ($l in $lines) {
        if ($l -match '^\s*([^:]+?)\s*:\s*(.*)$') {
            [pscustomobject]@{ Key = $matches[1].Trim(); Value = $matches[2].Trim() }
        }
    }
}

function Test-LocationBlock([string[]]$raw) {
    $txt = ($raw -join "`n")
    if ($txt -match '(?i)location|расположени|joylashuv') {
        Say "  Windows 11 netsh wlan buyruqlari uchun 'Joylashuv' (Location) ruxsatini talab qilyapti." Yellow
        Say "  Sozlamalar > Maxfiylik > Joylashuv > 'Ish stoli ilovalariga ruxsat' ni yoqing, so'ng qayta ishga tushiring." Yellow
        return $true
    }
    $false
}

function Get-WifiInfo {
    $raw = @(netsh wlan show interfaces 2>$null)
    [void](Test-LocationBlock $raw)
    $p = @(Get-NetshPairs $raw)
    $byKey = { param($rx) ($p | Where-Object { $_.Key -match $rx } | Select-Object -First 1).Value }
    $byVal = { param($rx) ($p | Where-Object { $_.Value -match $rx } | Select-Object -First 1).Value }

    $ch = & $byKey '^(Channel|Канал|Kanal)$'
    $chInt = $null; if ($ch -match '^\d+') { $chInt = [int]$matches[0] }
    $band = & $byKey '^(Band|Диапазон|Diapazon)$'
    if (-not $band) { $band = & $byVal '^\d+([.,]\d+)?\s*(GHz|ГГц)$' }
    if (-not $band) { $band = Get-BandFromChannel $chInt }
    if ($band) { $band = $band -replace ',', '.' -replace 'ГГц', 'GHz' }
    $sig = & $byVal '^\d+\s*%$'
    $sigInt = $null; if ($sig -match '^\d+') { $sigInt = [int]$matches[0] }
    $rssi = & $byKey '^Rssi$'
    if (-not $rssi -and $sigInt -ne $null) { $rssi = "~{0}" -f [int]($sigInt / 2 - 100) }

    [pscustomobject]@{
        SSID      = & $byKey '^SSID$'
        BSSID     = & $byKey '(?i)BSSID'
        Profile   = & $byKey '^(Profile|Профиль|Profil)$'
        RadioType = & $byVal '^802\.11'
        Band      = $band
        Channel   = $chInt
        Signal    = $sigInt
        Rssi      = $rssi
        RxRate    = & $byKey '(?i)(Receive|при[её]ма|qabul)'
        TxRate    = & $byKey '(?i)(Transmit|передачи|uzatish)'
    }
}

function Get-NeighborAPs {
    $raw = @(netsh wlan show networks mode=bssid 2>$null)
    if (Test-LocationBlock $raw) { return @() }
    $list = New-Object System.Collections.Generic.List[object]
    $ssid = $null; $cur = $null
    foreach ($l in $raw) {
        if ($l -match '^SSID\s+\d+\s*:\s*(.*)$') { $ssid = $matches[1].Trim(); continue }
        if ($l -match '^\s*BSSID\s+\d+\s*:\s*(\S+)') {
            if ($cur) { $list.Add([pscustomobject]$cur) }
            $cur = [ordered]@{ SSID = $ssid; BSSID = $matches[1]; Signal = $null; Channel = $null; Band = $null; ChanUtil = $null }
            continue
        }
        if ($cur -and $l -match '^\s*([^:]+?)\s*:\s*(.*)$') {
            $k = $matches[1].Trim(); $v = $matches[2].Trim()
            if ($v -match '^(\d+)\s*%$') { $cur.Signal = [int]$matches[1] }
            elseif ($k -match '^(Channel|Канал|Kanal)$' -and $v -match '^(\d+)') { $cur.Channel = [int]$matches[1] }
            elseif ($v -match '^\d+([.,]\d+)?\s*(GHz|ГГц)$') { $cur.Band = ($v -replace ',', '.' -replace 'ГГц', 'GHz') }
            elseif ($k -match '(?i)utiliz|загрузк|использован' -and $v -match '\((\d+)\s*%\)') { $cur.ChanUtil = [int]$matches[1] }
        }
    }
    if ($cur) { $list.Add([pscustomobject]$cur) }
    foreach ($x in $list) { if (-not $x.Band) { $x.Band = Get-BandFromChannel $x.Channel } }
    $list.ToArray()
}

function Get-DriverInfo($a) {
    $id = $a.PnPDeviceID -replace '\\', '\\'
    $drv = $null
    try { $drv = Get-CimInstance Win32_PnPSignedDriver -Filter "DeviceID='$id'" | Select-Object -First 1 } catch {}
    $ver = $a.DriverVersionString; $prov = $a.DriverProvider; $date = $a.DriverDate; $inf = $null; $mfr = $null
    if ($drv) {
        $ver = $drv.DriverVersion; $prov = $drv.DriverProviderName; $inf = $drv.InfName; $mfr = $drv.Manufacturer
        if ($drv.DriverDate) { $date = ([datetime]$drv.DriverDate).ToString('yyyy-MM-dd') }
    }
    $age = $null
    try { if ($date) { $age = [int]((Get-Date) - [datetime]$date).TotalDays } } catch {}
    [pscustomobject]@{ Version = $ver; Date = $date; AgeDays = $age; Provider = $prov; Manufacturer = $mfr; Inf = $inf }
}

function Get-PowerSource {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        switch ([string][System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus) {
            'Online' { 'Zaryadkada (AC)' } 'Offline' { 'Batareyada' } default { "Noma'lum" }
        }
    } catch { "Noma'lum" }
}

function Get-Snapshot {
    $a = Get-WifiAdapter; $w = Get-WifiInfo; $d = Get-DriverInfo $a
    [pscustomobject]@{
        Vaqt = (Get-Date).ToString('s'); Adapter = $a.InterfaceDescription; UlanishTezligi = $a.LinkSpeed
        SSID = $w.SSID; BSSID = $w.BSSID; Standart = $w.RadioType; Chastota = $w.Band; Kanal = $w.Channel
        SignalFoiz = $w.Signal; SignalDbm = $w.Rssi; QabulMbps = $w.RxRate; UzatishMbps = $w.TxRate
        DrayverVersiya = $d.Version; DrayverSana = $d.Date; DrayverYoshiKun = $d.AgeDays; DrayverProvayder = $d.Provider
        QuvvatManbai = Get-PowerSource
    }
}

# ----------------------------------------------------------------- 1/5: o'lchov
function Get-PingStats([object[]]$vals, [int]$spike) {
    $n = $vals.Count
    $ok = @($vals | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    $m = $ok.Count
    $res = [ordered]@{ Yuborildi = $n; Javob = $m; YoqotishFoiz = if ($n) { [math]::Round(100.0 * ($n - $m) / $n, 2) } else { 0 } }
    if ($m -eq 0) { return [pscustomobject]$res }
    $s = @($ok | Sort-Object)
    $med = if ($m % 2) { $s[[int](($m - 1) / 2)] } else { ($s[$m / 2 - 1] + $s[$m / 2]) / 2.0 }
    $k = [int][math]::Max(1, [math]::Ceiling($m * 0.01))
    $worst = @($s[($m - $k)..($m - 1)])
    $jsum = 0.0; $jumps = 0
    for ($i = 1; $i -lt $m; $i++) {
        $dd = [math]::Abs($ok[$i] - $ok[$i - 1]); $jsum += $dd; if ($dd -gt $spike) { $jumps++ }
    }
    $res.MinMs = $s[0]
    $res.OrtachaMs = [math]::Round(($ok | Measure-Object -Average).Average, 1)
    $res.MedianaMs = $med
    $res.MaxMs = $s[$m - 1]
    $res.P99Ms = $s[[int][math]::Min($m - 1, [math]::Ceiling(0.99 * $m) - 1)]
    $res.Eng1FoizOrtachaMs = [math]::Round(($worst | Measure-Object -Average).Average, 1)
    $res.JitterMs = if ($m -gt 1) { [math]::Round($jsum / ($m - 1), 1) } else { 0 }
    $res.Oshgan30 = @($ok | Where-Object { $_ -gt $spike }).Count
    $res.SakrashMediana30 = @($ok | Where-Object { $_ -gt ($med + $spike) }).Count
    $res.KeskinOzgarish30 = $jumps
    [pscustomobject]$res
}

function Get-PingRtt($task) {
    try {
        if ($task.Status -eq 'RanToCompletion' -and $task.Result.Status -eq 'Success') { return [int]$task.Result.RoundtripTime }
    } catch {}
    $null
}

function Invoke-Measure([string]$Label) {
    $tag = if ($Label -eq 'OLDIN') { 'oldin' } else { 'keyin' }
    Head "$Label o'lchov: $Minutes daqiqa (router va $Target, har soniyada)"
    Say "  Test davomida noutbukni joyidan qimirlatmang, katta yuklab olishlarni to'xtating." Yellow
    Say "  OLDIN va KEYIN testlari bir xil joyda va bir xil quvvat manbaida (zaryadka/batareya) o'tkazilsin." Yellow

    $a = Get-WifiAdapter
    $gw = (Get-NetIPConfiguration -InterfaceIndex $a.ifIndex).IPv4DefaultGateway | Select-Object -First 1 -ExpandProperty NextHop
    if (-not $gw) { throw "Router (default gateway) manzili topilmadi. Wi-Fi ulanganmi?" }
    $snapStart = Get-Snapshot
    Say ("  Router: {0}   Tarmoq: {1}   {2}, kanal {3}, signal {4}%" -f $gw, $snapStart.SSID, $snapStart.Chastota, $snapStart.Kanal, $snapStart.SignalFoiz)

    $total = $Minutes * 60
    $rows = New-Object System.Collections.Generic.List[object]
    $wlog = New-Object System.Collections.Generic.List[object]
    $sw = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $total; $i++) {
        $p1 = New-Object System.Net.NetworkInformation.Ping
        $p2 = New-Object System.Net.NetworkInformation.Ping
        $t1 = $null; $t2 = $null
        try { $t1 = $p1.SendPingAsync($gw, 1000) } catch {}
        try { $t2 = $p2.SendPingAsync($Target, 1000) } catch {}
        $tasks = [System.Threading.Tasks.Task[]]@(@($t1, $t2) | Where-Object { $_ })
        if ($tasks.Count) { try { [void][System.Threading.Tasks.Task]::WaitAll($tasks, 2500) } catch {} }
        $r1 = if ($t1) { Get-PingRtt $t1 } else { $null }
        $r2 = if ($t2) { Get-PingRtt $t2 } else { $null }
        $p1.Dispose(); $p2.Dispose()
        $rows.Add([pscustomobject]@{ Soniya = $i; Vaqt = (Get-Date).ToString('HH:mm:ss'); RouterMs = $r1; InternetMs = $r2 })

        if ($i % 15 -eq 0) {
            $w = Get-WifiInfo
            $wlog.Add([pscustomobject]@{ Soniya = $i; BSSID = $w.BSSID; Kanal = $w.Channel; Chastota = $w.Band; Signal = $w.Signal; Qabul = $w.RxRate })
        }
        if ($i % 5 -eq 0) {
            $last = @($rows | Select-Object -Last 60)
            $lr = @($last | Where-Object { $null -ne $_.RouterMs } | ForEach-Object { $_.RouterMs })
            $li = @($last | Where-Object { $null -ne $_.InternetMs } | ForEach-Object { $_.InternetMs })
            $st = "router oxirgi={0} max60s={1} | {2} oxirgi={3} max60s={4}" -f $r1, ($lr | Measure-Object -Maximum).Maximum, $Target, $r2, ($li | Measure-Object -Maximum).Maximum
            Write-Progress -Activity "$Label o'lchov" -Status $st -PercentComplete ([int](100 * $i / $total)) -SecondsRemaining ($total - $i)
        }
        $wait = ($i + 1) * 1000 - $sw.ElapsedMilliseconds
        if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
    }
    Write-Progress -Activity "$Label o'lchov" -Completed
    $snapEnd = Get-Snapshot

    $bssids = @($wlog | Where-Object { $_.BSSID } | ForEach-Object { $_.BSSID })
    $roams = 0; for ($j = 1; $j -lt $bssids.Count; $j++) { if ($bssids[$j] -ne $bssids[$j - 1]) { $roams++ } }
    $bandChanges = 0; $bands = @($wlog | Where-Object { $_.Chastota } | ForEach-Object { $_.Chastota })
    for ($j = 1; $j -lt $bands.Count; $j++) { if ($bands[$j] -ne $bands[$j - 1]) { $bandChanges++ } }

    $result = [pscustomobject]@{
        Bosqich = $Label; Boshlandi = $snapStart.Vaqt; Daqiqa = $Minutes; Router = $gw; Internet = $Target; SakrashChegarasiMs = $SpikeMs
        RouterStat = Get-PingStats @($rows | ForEach-Object { $_.RouterMs }) $SpikeMs
        InternetStat = Get-PingStats @($rows | ForEach-Object { $_.InternetMs }) $SpikeMs
        Rouming = $roams; ChastotaAlmashdi = $bandChanges
        Boshida = $snapStart; Oxirida = $snapEnd; WifiJurnal = $wlog.ToArray()
    }
    $rows | Export-Csv -Path (Join-Path $OutDir "${tag}_ping_$Stamp.csv") -NoTypeInformation -Encoding UTF8
    Save-Json $result (Join-Path $OutDir "${tag}_$Stamp.json")
    Show-Measure $result
    $result
}

function Show-Measure($r) {
    Head "$($r.Bosqich) natijasi"
    $rows = foreach ($p in @(
            @('Yoqotish, %', 'YoqotishFoiz'), @('Min, ms', 'MinMs'), @('Oddiy ping (mediana), ms', 'MedianaMs'),
            @("O'rtacha, ms", 'OrtachaMs'), @('Eng yomon (max), ms', 'MaxMs'), @('P99, ms', 'P99Ms'),
            @("Eng yomon 1% o'rtachasi, ms", 'Eng1FoizOrtachaMs'), @('Jitter, ms', 'JitterMs'),
            @("> $($r.SakrashChegarasiMs) ms pinglar soni", 'Oshgan30'),
            @("Sakrash (mediana+$($r.SakrashChegarasiMs) ms dan yuqori)", 'SakrashMediana30'),
            @("Keskin o'zgarish (ketma-ket farq > $($r.SakrashChegarasiMs) ms)", 'KeskinOzgarish30'))) {
        [pscustomobject]@{ "Ko'rsatkich" = $p[0]; "Router ($($r.Router))" = $r.RouterStat.($p[1]); "Internet ($($r.Internet))" = $r.InternetStat.($p[1]) }
    }
    $rows | Format-Table -AutoSize | Out-String | Write-Host
    $s = $r.Boshida
    Say ("  Adapter: {0}" -f $s.Adapter)
    Say ("  Ulanish tezligi: {0} (qabul {1} / uzatish {2} Mbit/s), standart {3}" -f $s.UlanishTezligi, $s.QabulMbps, $s.UzatishMbps, $s.Standart)
    Say ("  Chastota: {0}, kanal {1}, signal {2}% ({3} dBm)" -f $s.Chastota, $s.Kanal, $s.SignalFoiz, $s.SignalDbm)
    Say ("  Drayver: {0}, sana {1} ({2} kun oldin), {3}" -f $s.DrayverVersiya, $s.DrayverSana, $s.DrayverYoshiKun, $s.DrayverProvayder)
    Say ("  Rouming (BSSID almashishi): {0}, chastota almashishi: {1}, quvvat: {2}" -f $r.Rouming, $r.ChastotaAlmashdi, $s.QuvvatManbai)
}

# ----------------------------------------------------------------- sozlamalar
$WlanSub = '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1'   # Power Options > Wireless Adapter Settings
function Get-WlanPowerPlan {
    $out = @(powercfg /query SCHEME_CURRENT $WlanSub 2>$null)
    $guids = @(([regex]::Matches(($out -join "`n"), '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')) | ForEach-Object { $_.Value })
    $hex = @(([regex]::Matches(($out -join "`n"), '0x[0-9a-fA-F]{8}')) | ForEach-Object { [Convert]::ToInt32($_.Value, 16) })
    if ($guids.Count -lt 3 -or $hex.Count -lt 2) { return $null }
    [pscustomobject]@{ Setting = $guids[2]; AC = $hex[0]; DC = $hex[1] }
}
$PowerNames = @{ 0 = 'Maksimal unumdorlik'; 1 = 'Past tejash'; 2 = "O'rta tejash"; 3 = 'Maksimal tejash' }

function Find-Adv($adv, [string]$rx) {
    $adv | Where-Object { $_.DisplayName -match $rx -or $_.RegistryKeyword -match $rx } | Select-Object -First 1
}

$AdvRules = @(
    @{ Id = 'band';  Rx = '(?i)prefer.*band|band.*prefer|предпочт.*диапаз|RoamingPreferredBandType';  Name = 'Afzal chastota (Preferred Band)' },
    @{ Id = 'roam';  Rx = '(?i)roam|роуминг';                                                         Name = 'Rouming agressivligi' },
    @{ Id = 'coal';  Rx = '(?i)coalesc|объединен.*пакет|\*PacketCoalescing';                          Name = "Paketlarni birlashtirish (Packet Coalescing)" },
    @{ Id = 'mimo';  Rx = '(?i)MIMO';                                                                 Name = 'MIMO quvvat tejash' },
    @{ Id = 'uapsd'; Rx = '(?i)U-?APSD';                                                              Name = 'U-APSD quvvat tejash' },
    @{ Id = 'w24';   Rx = '(?i)2[.,]4.*(width|ширин)|(width|ширин).*2[.,]4|ChannelWidth24';           Name = '2.4 GHz kanal kengligi' }
)

# ----------------------------------------------------------------- 2/5: tahlil
function Invoke-Analyze {
    Head 'Tahlil'
    $a = Get-WifiAdapter; $w = Get-WifiInfo; $d = Get-DriverInfo $a; $n = @(Get-NeighborAPs)
    $adv = @(Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue)
    $f = New-Object System.Collections.Generic.List[object]
    function Add-F($sev, $what, $now, $fix) { $f.Add([pscustomobject]@{ Daraja = $sev; Muammo = $what; Holat = $now; Tavsiya = $fix }) }

    # O'lchov natijasi asosida: muammo Wi-Fi dami yoki provayderda
    $before = Get-Latest 'oldin_*.json'
    if ($before) {
        $b = Get-Content $before.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $rs = $b.RouterStat; $is = $b.InternetStat
        if ($rs.YoqotishFoiz -gt 0.5 -or $rs.P99Ms -gt 50 -or $rs.JitterMs -gt 5) {
            Add-F 'YUQORI' "Routergacha bo'lgan qism (Wi-Fi) beqaror" ("yo'qotish {0}%, P99 {1} ms, jitter {2} ms" -f $rs.YoqotishFoiz, $rs.P99Ms, $rs.JitterMs) "Muammo noutbuk-router oralig'ida: quyidagi Wi-Fi tuzatishlari ta'sir qiladi."
        } elseif ($is.YoqotishFoiz -gt 1 -or $is.JitterMs -gt 10) {
            Add-F "O'RTA" "Router yaxshi, lekin internet beqaror" ("router jitter {0} ms, internet jitter {1} ms, yo'qotish {2}%" -f $rs.JitterMs, $is.JitterMs, $is.YoqotishFoiz) "Sabab ehtimol provayder/router WAN tomonida. Wi-Fi sozlamalari kam yordam beradi."
        }
        if ($b.Rouming -gt 0) { Add-F "O'RTA" 'Test paytida rouming (BSSID almashdi)' "$($b.Rouming) marta" "Bitta router bo'lsa rouming agressivligini pasaytirish." }
        if ($b.ChastotaAlmashdi -gt 0) { Add-F "O'RTA" "Test paytida 2.4/5 GHz o'rtasida sakradi" "$($b.ChastotaAlmashdi) marta" "Afzal chastotani 5 GHz qilish." }
    } else { Say "  OLDIN o'lchov topilmadi - avval -Step Before ni ishga tushiring (tahlil to'liqroq bo'ladi)." Yellow }

    # Chastota va signal
    if ($w.Band -match '^2\.4') {
        $same5 = @($n | Where-Object { $_.SSID -eq $w.SSID -and $_.Band -match '^(5|6)' })
        $other5 = @($n | Where-Object { $_.SSID -ne $w.SSID -and $_.Band -match '^(5|6)' -and $_.SSID -like "*$($w.SSID)*" })
        $hint = if ($same5) { "Shu tarmoqning 5 GHz nuqtasi ko'rinyapti ($($same5[0].Signal)%)." } elseif ($other5) { "5 GHz tarmoq topildi: $($other5[0].SSID)" } else { "5 GHz tarmoq ko'rinmadi - routerda 5 GHz o'chiq bo'lishi mumkin." }
        Add-F 'YUQORI' '2.4 GHz da ishlayapti' "kanal $($w.Channel)" "5 GHz ga o'tish. $hint"
    }
    if ($w.Signal -ne $null -and $w.Signal -lt 60) { Add-F 'YUQORI' 'Signal kuchsiz' "$($w.Signal)% ($($w.Rssi) dBm)" "Routerga yaqinlashish/to'siqlarni kamaytirish; 5 GHz devor orqali kuchsizroq bo'lishini hisobga oling." }

    # Kanal bandligi
    if ($w.Channel) {
        $others = @($n | Where-Object { $_.SSID -ne $w.SSID -and $_.Channel })
        if ($w.Band -match '^2\.4') { $ov = @($others | Where-Object { [math]::Abs($_.Channel - $w.Channel) -lt 5 }) }
        else { $ov = @($others | Where-Object { $_.Channel -eq $w.Channel }) }
        $util = ($n | Where-Object { $_.BSSID -eq $w.BSSID } | Select-Object -First 1).ChanUtil
        $strong = @($ov | Where-Object { $_.Signal -ge 40 }).Count
        if ($ov.Count -ge 3 -or $strong -ge 2 -or $util -gt 50) {
            Add-F 'YUQORI' 'Kanal tirband' ("kanal {0}: {1} ta qo'shni tarmoq ({2} tasi kuchli){3}" -f $w.Channel, $ov.Count, $strong, $(if ($util) { ", kanal bandligi $util%" } else { '' })) (Get-ChannelAdvice $n $w)
        }
    }

    # Drayver
    if ($d.AgeDays -gt 365) { Add-F "O'RTA" 'Drayver eski' "$($d.Version), $($d.Date) ($($d.AgeDays) kun)" "Windows Update yoki ishlab chiqaruvchi saytidan yangilash." }

    # Quvvat tejash
    try {
        $pm = Get-NetAdapterPowerManagement -Name $a.Name
        if ([string]$pm.AllowComputerToTurnOffDevice -eq 'Enabled') { Add-F "O'RTA" "Adapterni quvvat tejash uchun o'chirishga ruxsat berilgan" 'Enabled' "O'chirish (Disabled)." }
    } catch {}
    $pp = Get-WlanPowerPlan
    if ($pp -and ($pp.AC -ne 0 -or $pp.DC -ne 0)) { Add-F "O'RTA" "Quvvat rejasida Wi-Fi tejash rejimi" ("zaryadka: {0}, batareya: {1}" -f $PowerNames[$pp.AC], $PowerNames[$pp.DC]) "Ikkalasini 'Maksimal unumdorlik' qilish." }

    # Adapter kengaytirilgan sozlamalari
    foreach ($r in $AdvRules) {
        $p = Find-Adv $adv $r.Rx
        if (-not $p) { continue }
        $v = [string]$p.DisplayValue
        switch ($r.Id) {
            'band'  { if ($v -notmatch '5') { Add-F "O'RTA" $r.Name $v "5 GHz ni afzal ko'rish." } }
            'roam'  { if ($v -notmatch '(?i)lowest|самый низк|conservative|disabled|откл|low|низк') { Add-F 'PAST' $r.Name $v "Bitta router bo'lsa - eng past; mesh bo'lsa - o'rta-past." } }
            'coal'  { if ($v -match '(?i)enabled|включ|^on$') { Add-F 'PAST' $r.Name $v "O'chirish (paketlar kechiktirib yuborilmaydi)." } }
            'mimo'  { if ($v -notmatch '(?i)no\s*SMPS|disabled|откл') { Add-F 'PAST' $r.Name $v "'No SMPS' (tejashsiz)." } }
            'uapsd' { if ($v -match '(?i)enabled|включ|^on$') { Add-F 'PAST' $r.Name $v "O'chirish." } }
            'w24'   { if ($w.Band -match '^2\.4' -and $v -notmatch '^20|20\s*MHz') { Add-F 'PAST' $r.Name $v "2.4 GHz da qolsangiz 20 MHz (kamroq to'qnashuv)." } }
        }
    }

    if ($f.Count -eq 0) { Say '  Jiddiy muammo topilmadi.' Green }
    else { $f | Format-List | Out-String | Write-Host }

    Say '  Qo''shni tarmoqlar (eng kuchli 15 tasi):'
    $n | Sort-Object Signal -Descending | Select-Object -First 15 SSID, BSSID, Band, Channel, Signal, ChanUtil | Format-Table -AutoSize | Out-String | Write-Host
    Say ("  Kanal maslahati: " + (Get-ChannelAdvice $n $w))
    $adv | Select-Object DisplayName, DisplayValue, RegistryKeyword, RegistryValue | Export-Csv (Join-Path $OutDir "adapter_sozlamalari_$Stamp.csv") -NoTypeInformation -Encoding UTF8
    Save-Json ([pscustomobject]@{ Wifi = $w; Drayver = $d; Topilmalar = $f.ToArray(); Qoshnilar = $n }) (Join-Path $OutDir "tahlil_$Stamp.json")
    $f.ToArray()
}

function Get-ChannelAdvice($n, $w) {
    $others = @($n | Where-Object { $_.SSID -ne $w.SSID -and $_.Channel })
    $score24 = foreach ($c in 1, 6, 11) {
        $s = (@($others | Where-Object { $_.Band -match '^2\.4' -and [math]::Abs($_.Channel - $c) -lt 5 } | ForEach-Object { $_.Signal }) | Measure-Object -Sum).Sum
        [pscustomobject]@{ C = $c; S = [int]$s }
    }
    $best24 = ($score24 | Sort-Object S | Select-Object -First 1).C
    $score5 = foreach ($c in 36, 40, 44, 48, 149, 153, 157, 161) {
        $s = (@($others | Where-Object { $_.Channel -eq $c } | ForEach-Object { $_.Signal }) | Measure-Object -Sum).Sum
        [pscustomobject]@{ C = $c; S = [int]$s }
    }
    $best5 = ($score5 | Sort-Object S | Select-Object -First 1).C
    "Router sozlamalarida (bu noutbukdan o'zgartirib bo'lmaydi): 2.4 GHz uchun kanal $best24 (20 MHz), 5 GHz uchun kanal $best5 eng bo'sh ko'rinadi."
}

# ----------------------------------------------------------------- 3/5: zaxira
function Backup-Settings {
    Head 'Joriy sozlamalarni zaxiralash'
    $a = Get-WifiAdapter
    $adv = @(Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{ DisplayName = $_.DisplayName; DisplayValue = $_.DisplayValue; RegistryKeyword = $_.RegistryKeyword; RegistryValue = @($_.RegistryValue) } })
    $pm = $null; try { $pm = [string](Get-NetAdapterPowerManagement -Name $a.Name).AllowComputerToTurnOffDevice } catch {}
    $d = Get-DriverInfo $a
    $bk = [pscustomobject]@{
        Vaqt = (Get-Date).ToString('s'); AdapterName = $a.Name; Adapter = $a.InterfaceDescription
        Profil = (Get-WifiInfo).Profile; Drayver = $d; AllowComputerToTurnOffDevice = $pm; QuvvatRejasi = Get-WlanPowerPlan; Advanced = $adv
    }
    $path = Join-Path $OutDir "zaxira_$Stamp.json"
    Save-Json $bk $path
    if ($d.Inf -and $d.Inf -match '^oem\d+\.inf$') {
        $ddir = Join-Path $OutDir "drayver_zaxira_$Stamp"
        New-Item -ItemType Directory -Force -Path $ddir | Out-Null
        pnputil /export-driver $d.Inf $ddir | Out-Null
        Say "  Joriy drayver nusxasi: $ddir" DarkGray
    }
    $path
}

# ----------------------------------------------------------------- 4/5: tuzatish
function Set-AdvSetting($adapterName, $rule, [string[]]$want, [string]$why) {
    $p = Find-Adv @(Get-NetAdapterAdvancedProperty -Name $adapterName) $rule.Rx
    if (-not $p) { Say "  [$($rule.Name)] bu adapterda yo'q - o'tkazildi." DarkGray; return $false }
    $target = $null
    foreach ($rx in $want) { $target = $p.ValidDisplayValues | Where-Object { $_ -match $rx } | Select-Object -First 1; if ($target) { break } }
    if ($target -and $p.DisplayValue -eq $target) { Say "  [$($p.DisplayName)] allaqachon '$target' - o'zgarish kerak emas." Green; return $false }
    Write-Host ''
    Say "  Sozlama : $($p.DisplayName)" White
    Say "  Hozir   : $($p.DisplayValue)"
    Say "  Mumkin  : $($p.ValidDisplayValues -join ' | ')" DarkGray
    Say "  Nega    : $why"
    if (-not $target) {
        $target = (Read-Host "  Mos qiymat avtomatik topilmadi. Ro'yxatdan qiymatni aynan yozing (bo'sh = o'tkazish)").Trim()
        if (-not $target -or $p.ValidDisplayValues -notcontains $target) { Say '  O''tkazildi.' DarkGray; return $false }
    }
    Say "  Yangi   : $target" Yellow
    if (-not (Ask "  '$($p.DisplayName)' ni '$($p.DisplayValue)' -> '$target' ga o'zgartiraymi?")) { return $false }
    Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName $p.DisplayName -DisplayValue $target -NoRestart
    Say '  Bajarildi.' Green
    $true
}

function Invoke-Fix {
    if (-not (Test-Admin)) { throw "Tuzatish bosqichi uchun PowerShell'ni 'Administrator sifatida' oching." }
    Head 'Tuzatish (har bir qadam ruxsat bilan)'
    $bk = Backup-Settings
    Say "  Hammasini qaytarish: .\wifi-diag.ps1 -Step Restore -BackupFile `"$bk`"" Yellow
    if (Ask "  Drayver yangilashdan oldin Windows tiklash nuqtasi (System Restore) yaratilsinmi?") {
        try { Checkpoint-Computer -Description "wifi-diag $Stamp" -RestorePointType MODIFY_SETTINGS; Say '  Tiklash nuqtasi yaratildi.' Green }
        catch { Say "  Yaratib bo'lmadi: $($_.Exception.Message)" Yellow }
    }

    $a = Get-WifiAdapter; $w = Get-WifiInfo
    $needRestart = $false

    # 1) Adapterning quvvat tejashi
    Head '1. Adapterning quvvat tejashi'
    try {
        $pm = Get-NetAdapterPowerManagement -Name $a.Name
        if ([string]$pm.AllowComputerToTurnOffDevice -eq 'Enabled') {
            Say "  Reja: 'Quvvatni tejash uchun kompyuterga bu qurilmani o'chirishga ruxsat berish' -> O'CHIRISH."
            Say "  Nega: Windows adapterni uxlatib qo'yib, uyg'otganda ping sakrashlari va uzilishlar bo'ladi."
            if (Ask '  Bajaraymi?') { Set-NetAdapterPowerManagement -Name $a.Name -AllowComputerToTurnOffDevice Disabled; $needRestart = $true; Say '  Bajarildi.' Green }
        } else { Say "  Allaqachon o'chiq yoki qo'llab-quvvatlanmaydi ($($pm.AllowComputerToTurnOffDevice))." Green }
    } catch { Say "  O'zgartirib bo'lmadi: $($_.Exception.Message). Qurilmalar dispetcheri > adapter > Quvvat boshqaruvi orqali qo'lda qiling." Yellow }

    $pp = Get-WlanPowerPlan
    if ($pp -and ($pp.AC -ne 0 -or $pp.DC -ne 0)) {
        Say ("  Reja: Quvvat rejasi > Simsiz adapter: zaryadka '{0}', batareya '{1}' -> ikkalasi 'Maksimal unumdorlik'." -f $PowerNames[$pp.AC], $PowerNames[$pp.DC])
        Say "  Nega: tejash rejimida adapter paketlar orasida uxlaydi - ping tebranadi. Batareya sarfi biroz oshadi."
        if (Ask '  Bajaraymi?') {
            powercfg /setacvalueindex SCHEME_CURRENT $WlanSub $pp.Setting 0
            powercfg /setdcvalueindex SCHEME_CURRENT $WlanSub $pp.Setting 0
            powercfg /setactive SCHEME_CURRENT
            Say '  Bajarildi.' Green
        }
    }

    # 2) Adapter kengaytirilgan sozlamalari
    Head '2. Adapter sozlamalari (rouming, chastota ustuvorligi, paket birlashtirish)'
    $r = $AdvRules | Where-Object { $_.Id -eq 'band' }
    if (Set-AdvSetting $a.Name $r @('(?i)prefer.*5\s*G|5\s*GHz|5\s*ГГц') "Router ikkala diapazonni bersa, noutbuk 5 GHz ni tanlaydi (kamroq shovqin, ko'proq tezlik).") { $needRestart = $true }

    $mesh = Ask "  Uyda bir nechta kirish nuqtasi (mesh, repiter, ikkinchi router) bormi?"
    $r = $AdvRules | Where-Object { $_.Id -eq 'roam' }
    if ($mesh) { $want = @('(?i)medium.?low|o.rta.?past|ниже средн|moderate', '(?i)medium|средн') ; $why = "Mesh bor: o'rta-past - keraksiz sakrashlar kamayadi, lekin xonalar orasida o'tish ishlaydi." }
    else { $want = @('(?i)lowest|самый низк|conservative|минимал', '(?i)^\D*low|низк'); $why = "Bitta router: noutbuk boshqa nuqta qidirib skanerlamaydi - skanerlash paytidagi ping sakrashlari yo'qoladi." }
    if (Set-AdvSetting $a.Name $r $want $why) { $needRestart = $true }

    $r = $AdvRules | Where-Object { $_.Id -eq 'coal' }
    if (Set-AdvSetting $a.Name $r @('(?i)^disabled$|откл|выкл|^off$') "Paketlarni to'plab kechiktirib yuborish ping va jitterni oshiradi.") { $needRestart = $true }
    $r = $AdvRules | Where-Object { $_.Id -eq 'mimo' }
    if (Set-AdvSetting $a.Name $r @('(?i)no\s*SMPS|без SMPS|disabled|откл') "MIMO quvvat tejash antennalarni o'chirib qo'yadi - tezlik va barqarorlik tushadi.") { $needRestart = $true }
    $r = $AdvRules | Where-Object { $_.Id -eq 'uapsd' }
    if (Set-AdvSetting $a.Name $r @('(?i)^disabled$|откл|выкл|^off$') "U-APSD - quvvat tejash, kechikish qo'shadi.") { $needRestart = $true }
    if ($w.Band -match '^2\.4') {
        $r = $AdvRules | Where-Object { $_.Id -eq 'w24' }
        if (Set-AdvSetting $a.Name $r @('(?i)^20\s*MHz|^20\s*МГц|^20') "Tirband 2.4 GHz da 40 MHz qo'shnilar bilan to'qnashadi; 20 MHz barqarorroq.") { $needRestart = $true }
    }

    if ($needRestart) {
        Say "`n  Sozlamalar kuchga kirishi uchun Wi-Fi adapterni qayta ishga tushirish kerak (internet 5-15 soniyaga uziladi)."
        if (Ask '  Adapterni qayta ishga tushiraymi?') { Restart-NetAdapter -Name $a.Name -Confirm:$false; Wait-WifiUp }
    }

    # 3) 5 GHz ga o'tish
    Head "3. 5 GHz ga o'tish"
    $w = Get-WifiInfo; $n = @(Get-NeighborAPs)
    if ($w.Band -notmatch '^2\.4') { Say "  Allaqachon $($w.Band) da (kanal $($w.Channel))." Green }
    else {
        $same5 = @($n | Where-Object { $_.SSID -eq $w.SSID -and $_.Band -match '^(5|6)' } | Sort-Object Signal -Descending)
        $profiles = @(netsh wlan show profiles 2>$null | ForEach-Object { if ($_ -match ':\s*(.+)$') { $matches[1].Trim() } })
        $alt = @($n | Where-Object { $_.SSID -and $_.SSID -ne $w.SSID -and $_.Band -match '^(5|6)' -and $profiles -contains $_.SSID } | Sort-Object Signal -Descending)
        if ($same5) {
            Say "  Shu tarmoqning 5 GHz nuqtasi bor (signal $($same5[0].Signal)%). Afzal chastota sozlamasidan keyin qayta ulanish kifoya."
            if (Ask "  '$($w.Profile)' ga uzib-qayta ulanaymi?") { netsh wlan disconnect | Out-Null; Start-Sleep 2; netsh wlan connect name="$($w.Profile)" | Out-Null; Wait-WifiUp }
        } elseif ($alt) {
            Say "  Saqlangan 5 GHz tarmoq topildi: '$($alt[0].SSID)' (signal $($alt[0].Signal)%)."
            if (Ask "  '$($alt[0].SSID)' ga ulanaymi?") { netsh wlan connect name="$($alt[0].SSID)" | Out-Null; Wait-WifiUp }
        } else {
            $cand = @($n | Where-Object { $_.Band -match '^(5|6)' -and $_.SSID -like "*$($w.SSID)*" })
            if ($cand) { Say "  5 GHz tarmoq ko'rinyapti: '$($cand[0].SSID)'. Unga Wi-Fi menyusidan parol bilan qo'lda ulaning, keyin skriptni qayta ishga tushiring." Yellow }
            else { Say "  5 GHz tarmoq ko'rinmadi. Router sozlamalarida 5 GHz ni yoqing (kanal 36-48, 80 MHz)." Yellow }
            Say ('  ' + (Get-ChannelAdvice $n $w))
        }
    }

    # 4) Drayver
    Head '4. Drayver'
    Update-WifiDriver

    Head 'Tuzatish tugadi'
    Say "  Zaxira fayli: $bk"
    Say "  Endi KEYIN o'lchovni o'tkazing (bir xil joyda, bir xil quvvat manbaida)."
}

function Wait-WifiUp {
    for ($i = 0; $i -lt 40; $i++) {
        Start-Sleep -Seconds 1
        $a = Get-WifiAdapter
        if ($a.Status -eq 'Up') {
            $gw = (Get-NetIPConfiguration -InterfaceIndex $a.ifIndex -ErrorAction SilentlyContinue).IPv4DefaultGateway
            if ($gw) { Say '  Wi-Fi qayta ulandi.' Green; Start-Sleep 3; return }
        }
    }
    Say "  Wi-Fi 40 soniyada ulanmadi - qo'lda tekshiring." Yellow
}

function Update-WifiDriver {
    $a = Get-WifiAdapter; $d = Get-DriverInfo $a
    Say ("  Hozirgi: {0} | versiya {1} | sana {2} ({3} kun) | {4}" -f $a.InterfaceDescription, $d.Version, $d.Date, $d.AgeDays, $d.Provider)
    if (Ask "  Windows Update'dan bu adapter uchun yangi drayver qidiraymi? (1-5 daqiqa)") {
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            Say '  Qidirilmoqda...'
            $res = $searcher.Search("IsInstalled=0 and Type='Driver'")
            $cands = @(); foreach ($u in $res.Updates) {
                if ($u.DriverClass -match '(?i)^net$' -or $u.Title -match '(?i)wireless|wi-?fi|wlan|802\.11|killer|network adapter') { $cands += $u }
            }
            if (-not $cands) { Say "  Windows Update'da yangi tarmoq drayveri yo'q." Green }
            foreach ($u in $cands) {
                Say ("  Topildi: {0} (sana {1})" -f $u.Title, $u.DriverVerDate)
                if (Ask '  Shu drayverni Windows Update orqali o''rnataymi? (internet bir necha soniya uzilishi mumkin)') {
                    if (-not $u.EulaAccepted) { $u.AcceptEula() }
                    $coll = New-Object -ComObject Microsoft.Update.UpdateColl; [void]$coll.Add($u)
                    $dl = $session.CreateUpdateDownloader(); $dl.Updates = $coll; [void]$dl.Download()
                    $inst = $session.CreateUpdateInstaller(); $inst.Updates = $coll; $r = $inst.Install()
                    Say ("  Natija kodi: {0} (2 = muvaffaqiyatli). Qayta yuklash kerak: {1}" -f $r.ResultCode, $r.RebootRequired) Green
                }
            }
        } catch { Say "  Windows Update qidiruvi ishlamadi: $($_.Exception.Message)" Yellow }
    }
    $cs = Get-CimInstance Win32_ComputerSystem
    Say ("  Noutbuk: {0} {1}" -f $cs.Manufacturer, $cs.Model)
    $desc = "$($a.InterfaceDescription) $($d.Provider)"
    if ($desc -match '(?i)intel|killer') {
        Say "  Intel/Killer adapter: rasmiy manba - Intel Driver & Support Assistant: https://www.intel.com/content/www/us/en/support/detect.html"
    } else {
        Say "  Realtek/MediaTek/Qualcomm/Broadcom adapterlar uchun rasmiy manba - noutbuk ishlab chiqaruvchisining qo'llab-quvvatlash sahifasi"
        Say "  (Lenovo Vantage, HP Support Assistant, Dell SupportAssist, ASUS MyASUS va h.k.), model: $($cs.Model)."
    }
    Say "  Uchinchi tomon 'driver updater' dasturlaridan foydalanmang."
    if (Ask "  Windows Update > Qo'shimcha yangilanishlar (Optional updates) sahifasini ochaymi?") { Start-Process 'ms-settings:windowsupdate-optionalupdates' }
}

# ----------------------------------------------------------------- qaytarish
function Invoke-Restore {
    if (-not (Test-Admin)) { throw "Qaytarish uchun PowerShell'ni 'Administrator sifatida' oching." }
    $file = if ($BackupFile) { Get-Item $BackupFile } else { Get-Latest 'zaxira_*.json' }
    if (-not $file) { throw 'Zaxira fayli topilmadi.' }
    Head "Zaxiradan qaytarish: $($file.Name)"
    $bk = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $name = $bk.AdapterName
    $cur = @(Get-NetAdapterAdvancedProperty -Name $name)
    $diff = @(foreach ($o in $bk.Advanced) {
            $c = $cur | Where-Object { $_.RegistryKeyword -eq $o.RegistryKeyword } | Select-Object -First 1
            if ($c -and ((@($c.RegistryValue) -join ',') -ne (@($o.RegistryValue) -join ','))) {
                [pscustomobject]@{ Sozlama = $o.DisplayName; Hozir = $c.DisplayValue; Qaytadi = $o.DisplayValue; Kw = $o.RegistryKeyword; Val = @($o.RegistryValue) }
            } })
    $pmNow = $null; try { $pmNow = [string](Get-NetAdapterPowerManagement -Name $name).AllowComputerToTurnOffDevice } catch {}
    $ppNow = Get-WlanPowerPlan
    if ($diff) { $diff | Select-Object Sozlama, Hozir, Qaytadi | Format-Table -AutoSize | Out-String | Write-Host }
    if ($bk.AllowComputerToTurnOffDevice -and $pmNow -ne $bk.AllowComputerToTurnOffDevice) { Say "  Quvvat boshqaruvi: $pmNow -> $($bk.AllowComputerToTurnOffDevice)" }
    if ($bk.QuvvatRejasi -and $ppNow -and ($ppNow.AC -ne $bk.QuvvatRejasi.AC -or $ppNow.DC -ne $bk.QuvvatRejasi.DC)) { Say "  Quvvat rejasi (AC/DC): $($ppNow.AC)/$($ppNow.DC) -> $($bk.QuvvatRejasi.AC)/$($bk.QuvvatRejasi.DC)" }
    if (-not (Ask '  Yuqoridagilarni eski holatiga qaytaraymi?')) { return }
    foreach ($x in $diff) { Set-NetAdapterAdvancedProperty -Name $name -RegistryKeyword $x.Kw -RegistryValue $x.Val -NoRestart }
    if ($bk.AllowComputerToTurnOffDevice -in @('Enabled', 'Disabled') -and $pmNow -ne $bk.AllowComputerToTurnOffDevice) {
        Set-NetAdapterPowerManagement -Name $name -AllowComputerToTurnOffDevice $bk.AllowComputerToTurnOffDevice
    }
    if ($bk.QuvvatRejasi -and $ppNow) {
        powercfg /setacvalueindex SCHEME_CURRENT $WlanSub $bk.QuvvatRejasi.Setting $bk.QuvvatRejasi.AC
        powercfg /setdcvalueindex SCHEME_CURRENT $WlanSub $bk.QuvvatRejasi.Setting $bk.QuvvatRejasi.DC
        powercfg /setactive SCHEME_CURRENT
    }
    Restart-NetAdapter -Name $name -Confirm:$false; Wait-WifiUp
    Say '  Sozlamalar qaytarildi.' Green
    $ddir = Join-Path $file.DirectoryName ($file.BaseName -replace '^zaxira_', 'drayver_zaxira_')
    $dNow = Get-DriverInfo (Get-WifiAdapter)
    if ((Test-Path $ddir) -and $dNow.Version -ne $bk.Drayver.Version) {
        Say "  Drayver o'zgargan: $($dNow.Version) (eski: $($bk.Drayver.Version))."
        Say "  Eng ishonchli yo'l: Qurilmalar dispetcheri > adapter > Drayver > 'Oldingi drayverga qaytish' (Roll Back)."
        if (Ask "  Yoki zaxiradagi eski drayverni pnputil bilan o'rnataymi?") {
            Get-ChildItem $ddir -Filter *.inf -Recurse | ForEach-Object { pnputil /add-driver $_.FullName /install }
            Say "  O'rnatildi. Windows yangisini tanlab qolsa, Roll Back yoki Qurilmalar dispetcherida drayverni qo'lda tanlang." Yellow
        }
    }
}

# ----------------------------------------------------------------- 5/5: taqqoslash
function Invoke-Compare {
    $bf = Get-Latest 'oldin_*.json'; $af = Get-Latest 'keyin_*.json'
    if (-not $bf -or -not $af) { throw "OLDIN va KEYIN natija fayllari kerak ($OutDir)." }
    $b = Get-Content $bf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $k = Get-Content $af.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    Head 'OLDIN / KEYIN'
    $metrics = @(
        @('Yoqotish, %', 'YoqotishFoiz'), @('Oddiy ping (mediana), ms', 'MedianaMs'), @("O'rtacha, ms", 'OrtachaMs'),
        @('Eng yomon (max), ms', 'MaxMs'), @('P99, ms', 'P99Ms'), @("Eng yomon 1% o'rtachasi, ms", 'Eng1FoizOrtachaMs'),
        @('Jitter, ms', 'JitterMs'), @("> $SpikeMs ms pinglar", 'Oshgan30'), @("Sakrashlar (mediana+$SpikeMs)", 'SakrashMediana30'),
        @("Keskin o'zgarishlar (>$SpikeMs)", 'KeskinOzgarish30'))
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($m in $metrics) {
        $rows.Add([pscustomobject]@{ "Ko'rsatkich" = $m[0]
                'Router OLDIN' = $b.RouterStat.($m[1]); 'Router KEYIN' = $k.RouterStat.($m[1])
                "$($b.Internet) OLDIN" = $b.InternetStat.($m[1]); "$($k.Internet) KEYIN" = $k.InternetStat.($m[1]) })
    }
    $info = @(@('Ulanish tezligi', 'UlanishTezligi'), @('Chastota', 'Chastota'), @('Kanal', 'Kanal'), @('Signal, %', 'SignalFoiz'),
        @('Signal, dBm', 'SignalDbm'), @('Standart', 'Standart'), @('Drayver versiyasi', 'DrayverVersiya'), @('Drayver sanasi', 'DrayverSana'), @('Quvvat manbai', 'QuvvatManbai'))
    $rows2 = foreach ($m in $info) { [pscustomobject]@{ 'Parametr' = $m[0]; 'OLDIN' = $b.Boshida.($m[1]); 'KEYIN' = $k.Boshida.($m[1]) } }
    $rows2 += [pscustomobject]@{ 'Parametr' = 'Rouming (test davomida)'; 'OLDIN' = $b.Rouming; 'KEYIN' = $k.Rouming }
    $rows | Format-Table -AutoSize | Out-String | Write-Host
    $rows2 | Format-Table -AutoSize | Out-String | Write-Host

    $md = New-Object System.Text.StringBuilder
    [void]$md.AppendLine("# Wi-Fi: OLDIN / KEYIN`n")
    [void]$md.AppendLine("OLDIN: $($b.Boshlandi), $($b.Daqiqa) daq. | KEYIN: $($k.Boshlandi), $($k.Daqiqa) daq. | Router: $($b.Router) | Internet: $($b.Internet)`n")
    foreach ($tbl in @($rows.ToArray(), $rows2)) {
        $cols = @($tbl[0].PSObject.Properties.Name)
        [void]$md.AppendLine('| ' + ($cols -join ' | ') + ' |')
        [void]$md.AppendLine('|' + (($cols | ForEach-Object { '---' }) -join '|') + '|')
        foreach ($r in $tbl) { [void]$md.AppendLine('| ' + (($cols | ForEach-Object { $r.$_ }) -join ' | ') + ' |') }
        [void]$md.AppendLine('')
    }
    $path = Join-Path $OutDir "taqqoslash_$Stamp.md"
    $md.ToString() | Set-Content -Path $path -Encoding UTF8
    Say "  Jadval saqlandi: $path" DarkGray
}

# ----------------------------------------------------------------- asosiy
try {
    switch ($Step) {
        'Before'  { [void](Invoke-Measure 'OLDIN') }
        'After'   { [void](Invoke-Measure 'KEYIN') }
        'Analyze' { [void](Invoke-Analyze) }
        'Fix'     { Invoke-Fix }
        'Restore' { Invoke-Restore }
        'Compare' { Invoke-Compare }
        'All' {
            if (-not (Test-Admin)) { throw "To'liq rejim uchun PowerShell'ni 'Administrator sifatida' oching (tuzatish bosqichiga kerak)." }
            [void](Invoke-Measure 'OLDIN')
            [void](Invoke-Analyze)
            if (Ask "`nTuzatish bosqichiga o'tamizmi? (har bir o'zgarish alohida so'raladi)") { Invoke-Fix }
            Read-Host "`nKEYIN o'lchovni boshlash uchun Enter bosing (drayver o'rnatilib, qayta yuklash so'ralgan bo'lsa - avval qayta yuklang va -Step After ni ishga tushiring)" | Out-Null
            [void](Invoke-Measure 'KEYIN')
            Invoke-Compare
        }
    }
} catch {
    Say "XATO: $($_.Exception.Message)" Red
    exit 1
}
