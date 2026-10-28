<#
    Fast Clear - Windows temizleme ve optimizasyon araci
    Hicbir sey onay almadan silinmez. Once tarama (onizleme) yapilir.
#>
param([switch]$ScanOnly)

$AppVersion = '1.0.0'
$ErrorActionPreference = 'SilentlyContinue'
$Host.UI.RawUI.WindowTitle = 'Fast Clear'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# .exe olarak derlendiginde $PSCommandPath bos olur; calisan dosyanin yolunu surecten aliriz.
$AppPath = if ($PSCommandPath) { $PSCommandPath } else { [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName }
$IsExe   = $AppPath -like '*.exe'
$LogDir  = Join-Path $env:LOCALAPPDATA 'FastClear\logs'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir ("FastClear_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Log([string]$Text) {
    Add-Content -LiteralPath $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Text) -Encoding UTF8
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
    return '{0:N0} B' -f $Bytes
}

function Confirm-Action([string]$Question) {
    $answer = Read-Host "$Question (E/H)"
    return ($answer -match '^(e|evet|y|yes)$')
}

function Pause-Menu { [void](Read-Host "`nDevam etmek icin Enter'a basin") }

function Write-Header([string]$Title) {
    Clear-Host
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host "  FAST CLEAR  |  $Title" -ForegroundColor Cyan
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host ''
}

# --- Temizlik kategorileri -------------------------------------------------

# Verilen klasorlerin (joker karakter destekli) icindeki ogeleri dondurur; klasorun kendisi silinmez.
function Get-FolderContents([string[]]$Paths, [int]$MinAgeHours = 0) {
    $limit = (Get-Date).AddHours(-$MinAgeHours)
    foreach ($p in $Paths) {
        foreach ($dir in (Get-Item -Path $p -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })) {
            Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue |
                Where-Object { $MinAgeHours -eq 0 -or $_.LastWriteTime -lt $limit }
        }
    }
}

function Get-BrowserCachePaths {
    $l = $env:LOCALAPPDATA
    $chromium = @(
        "$l\Google\Chrome\User Data",
        "$l\Microsoft\Edge\User Data",
        "$l\BraveSoftware\Brave-Browser\User Data",
        "$l\Vivaldi\User Data"
    )
    $paths = foreach ($root in $chromium) {
        foreach ($sub in 'Cache', 'Code Cache', 'GPUCache') { "$root\*\$sub" }
    }
    $paths += "$l\Opera Software\Opera*\Cache"
    $paths += "$l\Mozilla\Firefox\Profiles\*\cache2"
    return $paths
}

$Categories = @(
    [pscustomobject]@{ Key = 1; Name = 'Kullanici gecici dosyalari (24 saatten eski)'; Admin = $false
        Get = { Get-FolderContents @($env:TEMP) 24 } }
    [pscustomobject]@{ Key = 2; Name = 'Windows gecici dosyalari (24 saatten eski)'; Admin = $true
        Get = { Get-FolderContents @("$env:SystemRoot\Temp") 24 } }
    [pscustomobject]@{ Key = 3; Name = 'Tarayici onbellekleri (Chrome, Edge, Firefox, Brave, Opera)'; Admin = $false
        Get = { Get-FolderContents (Get-BrowserCachePaths) } }
    [pscustomobject]@{ Key = 4; Name = 'Windows Update indirme onbellegi'; Admin = $true
        Get = { Get-FolderContents @("$env:SystemRoot\SoftwareDistribution\Download") } }
    [pscustomobject]@{ Key = 5; Name = 'Hata raporlari ve cokme dokumleri'; Admin = $false
        Get = { Get-FolderContents @(
                    "$env:LOCALAPPDATA\CrashDumps",
                    "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
                    "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue",
                    "$env:ProgramData\Microsoft\Windows\WER\ReportArchive",
                    "$env:ProgramData\Microsoft\Windows\WER\ReportQueue",
                    "$env:SystemRoot\Minidump") } }
    [pscustomobject]@{ Key = 6; Name = 'Kucuk resim (thumbnail) onbellegi'; Admin = $false
        Get = { Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache_*.db' -Force } }
    [pscustomobject]@{ Key = 7; Name = 'DirectX golgelendirici onbellegi'; Admin = $false
        Get = { Get-FolderContents @("$env:LOCALAPPDATA\D3DSCache") } }
)

function Get-ItemSize($Item) {
    if ($Item.PSIsContainer) {
        $sum = (Get-ChildItem -LiteralPath $Item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        if ($sum) { return [double]$sum } else { return 0 }
    }
    return [double]$Item.Length
}

function Get-RecycleBinSize {
    $total = 0; $count = 0
    try {
        $shell = New-Object -ComObject Shell.Application
        foreach ($i in $shell.Namespace(10).Items()) { $total += [double]$i.Size; $count++ }
    } catch {}
    return [pscustomobject]@{ Size = $total; Count = $count }
}

function Invoke-Scan {
    Write-Host 'Taraniyor, lutfen bekleyin...' -ForegroundColor Yellow
    $isAdmin = Test-Admin
    $results = foreach ($c in $Categories) {
        $items = @(& $c.Get)
        $size = 0
        foreach ($i in $items) { $size += Get-ItemSize $i }
        [pscustomobject]@{ Category = $c; Items = $items; Size = $size
                           Skipped = ($c.Admin -and -not $isAdmin) }
    }
    $rb = Get-RecycleBinSize
    return [pscustomobject]@{ Results = $results; RecycleBin = $rb }
}

function Show-Scan($Scan) {
    Write-Host ''
    Write-Host ('{0,-4}{1,-62}{2,12}' -f 'No', 'Kategori', 'Boyut') -ForegroundColor White
    Write-Host ('-' * 78)
    $total = 0
    foreach ($r in $Scan.Results) {
        $note = ''
        if ($r.Skipped) { $note = ' (yonetici gerekli)' }
        Write-Host ('{0,-4}{1,-62}{2,12}' -f $r.Category.Key, ($r.Category.Name + $note), (Format-Size $r.Size))
        $total += $r.Size
    }
    Write-Host ('{0,-4}{1,-62}{2,12}' -f 8, ("Geri Donusum Kutusu ($($Scan.RecycleBin.Count) oge)"), (Format-Size $Scan.RecycleBin.Size))
    $total += $Scan.RecycleBin.Size
    Write-Host ('-' * 78)
    Write-Host ('{0,-66}{1,12}' -f 'TOPLAM kazanilabilecek alan (yaklasik)', (Format-Size $total)) -ForegroundColor Green
}

function Get-RunningBrowsers {
    $names = 'chrome', 'msedge', 'firefox', 'brave', 'opera', 'vivaldi'
    Get-Process -Name $names -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName -Unique
}

function Invoke-Clean {
    Write-Header 'Temizlik'
    $scan = Invoke-Scan
    Show-Scan $scan
    Write-Host ''
    Write-Host "Temizlenecek kategorilerin numaralarini virgulle yazin (ornek: 1,3,8)," -ForegroundColor Yellow
    Write-Host "hepsi icin 'T', vazgecmek icin bos birakin." -ForegroundColor Yellow
    $choice = Read-Host 'Seciminiz'
    if ([string]::IsNullOrWhiteSpace($choice)) { return }

    if ($choice -match '^(t|tumu|hepsi|a|all)$') { $keys = 1..8 }
    else { $keys = $choice -split '[,; ]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } }

    $selected = @($scan.Results | Where-Object { $keys -contains $_.Category.Key -and -not $_.Skipped })
    $doRecycle = $keys -contains 8
    if (-not $selected -and -not $doRecycle) { Write-Host 'Gecerli bir secim yapilmadi.'; return }

    if ($selected | Where-Object { $_.Category.Key -eq 3 }) {
        $open = @(Get-RunningBrowsers)
        if ($open) {
            Write-Host ''
            Write-Host ("Acik tarayicilar: {0}. Onbellek tam temizlenmesi icin kapatmaniz onerilir." -f ($open -join ', ')) -ForegroundColor Yellow
        }
    }

    Write-Host ''
    Write-Host 'Silinecekler:' -ForegroundColor White
    foreach ($r in $selected) { Write-Host (" - {0}  ({1})" -f $r.Category.Name, (Format-Size $r.Size)) }
    if ($doRecycle) { Write-Host (" - Geri Donusum Kutusu  ({0})" -f (Format-Size $scan.RecycleBin.Size)) }
    Write-Host ''
    if (-not (Confirm-Action 'Bu dosyalar KALICI olarak silinecek. Onayliyor musunuz?')) {
        Write-Host 'Iptal edildi, hicbir sey silinmedi.' -ForegroundColor Yellow
        return
    }

    $freed = 0
    foreach ($r in $selected) {
        Write-Host ("Temizleniyor: {0}" -f $r.Category.Name) -ForegroundColor Cyan
        Write-Log ("KATEGORI: {0}" -f $r.Category.Name)
        foreach ($item in $r.Items) {
            $size = Get-ItemSize $item
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $item.FullName)) {
                $freed += $size
                Write-Log ("  silindi: {0}" -f $item.FullName)
            } else {
                # Kullanimdaki dosyalar silinemez; klasor kismen temizlenmis olabilir.
                $left = Get-ItemSize (Get-Item -LiteralPath $item.FullName -Force)
                $freed += [math]::Max(0, $size - $left)
                Write-Log ("  atlandi (kullanimda): {0}" -f $item.FullName)
            }
        }
    }
    if ($doRecycle -and $scan.RecycleBin.Count -gt 0) {
        Write-Host 'Temizleniyor: Geri Donusum Kutusu' -ForegroundColor Cyan
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        $freed += $scan.RecycleBin.Size - (Get-RecycleBinSize).Size
        Write-Log 'Geri Donusum Kutusu bosaltildi'
    }

    Write-Log ("Toplam bosaltilan: {0}" -f (Format-Size $freed))
    Write-Host ''
    Write-Host ("Tamamlandi. Bosaltilan alan: {0}" -f (Format-Size $freed)) -ForegroundColor Green
    Write-Host "Kullanimdaki dosyalar atlandi. Kayit: $LogFile" -ForegroundColor DarkGray
}

# --- Raporlar --------------------------------------------------------------

function Show-SystemReport {
    Write-Header 'Sistem ve disk raporu'
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Host ("Isletim sistemi : {0} ({1})" -f $os.Caption, $os.OSArchitecture)
    Write-Host ("Islemci         : {0}" -f $cpu.Name.Trim())
    $totalRam = $os.TotalVisibleMemorySize * 1KB
    $freeRam  = $os.FreePhysicalMemory * 1KB
    Write-Host ("Bellek (RAM)    : {0} / {1} kullaniliyor (%{2:N0})" -f (Format-Size ($totalRam - $freeRam)), (Format-Size $totalRam), ((1 - $freeRam / $totalRam) * 100))
    Write-Host ("Acik kalma suresi: {0} gun {1} saat" -f $uptime.Days, $uptime.Hours)
    if ($uptime.Days -ge 7) { Write-Host '  Ipucu: Bilgisayar uzun suredir yeniden baslatilmamis; yeniden baslatmak performansi artirabilir.' -ForegroundColor Yellow }

    Write-Host ''
    Write-Host 'Diskler:' -ForegroundColor White
    foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
        $usedPct = if ($d.Size) { (1 - $d.FreeSpace / $d.Size) * 100 } else { 0 }
        $bar = ('#' * [int]($usedPct / 5)).PadRight(20, '.')
        $color = if ($usedPct -ge 90) { 'Red' } elseif ($usedPct -ge 75) { 'Yellow' } else { 'Green' }
        Write-Host ("  {0}  [{1}] %{2,3:N0} dolu   bos: {3} / {4}" -f $d.DeviceID, $bar, $usedPct, (Format-Size $d.FreeSpace), (Format-Size $d.Size)) -ForegroundColor $color
    }

    Write-Host ''
    Write-Host 'En cok bellek kullanan 10 islem:' -ForegroundColor White
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host ("  {0,-35}{1,12}" -f $_.ProcessName, (Format-Size $_.WorkingSet64))
    }
    Pause-Menu
}

function Show-JunkScan {
    Write-Header 'Onemsiz dosya taramasi (onizleme - hicbir sey silinmez)'
    Show-Scan (Invoke-Scan)
    if (-not (Test-Admin)) {
        Write-Host ''
        Write-Host "Not: 'yonetici gerekli' satirlari icin programi yonetici olarak calistirin (menu 7)." -ForegroundColor DarkGray
    }
    Pause-Menu
}

function Show-Startup {
    Write-Header 'Baslangicta acilan programlar'
    $items = Get-CimInstance Win32_StartupCommand | Sort-Object Name
    if (-not $items) { Write-Host 'Kayitli baslangic programi bulunamadi.' }
    foreach ($s in $items) {
        Write-Host ("- {0}" -f $s.Name) -ForegroundColor White
        Write-Host ("    Komut : {0}" -f $s.Command) -ForegroundColor DarkGray
        Write-Host ("    Konum : {0}" -f $s.Location) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host 'Bu liste sadece bilgi amaclidir; program hicbir kaydi degistirmez.'
    Write-Host 'Gereksiz olanlari Gorev Yoneticisi > Baslangic sekmesinden devre disi birakabilirsiniz.'
    if (Confirm-Action 'Gorev Yoneticisi baslangic sekmesi acilsin mi?') {
        Start-Process taskmgr.exe -ArgumentList '/0 /startup'
    }
    Pause-Menu
}

function Show-LargeFiles {
    Write-Header 'Buyuk dosyalar'
    $min = Read-Host 'En az kac MB? (varsayilan 500)'
    if (-not ($min -match '^\d+$')) { $min = 500 }
    $root = $env:USERPROFILE
    Write-Host "$root icinde $min MB'den buyuk dosyalar araniyor..." -ForegroundColor Yellow
    $files = Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
             Where-Object { $_.Length -ge ([int64]$min * 1MB) } |
             Sort-Object Length -Descending | Select-Object -First 25
    if (-not $files) { Write-Host 'Bulunamadi.' }
    foreach ($f in $files) {
        Write-Host ("{0,12}  {1}" -f (Format-Size $f.Length), $f.FullName)
    }
    Write-Host ''
    Write-Host 'Bu dosyalar silinmez; ihtiyaciniz yoksa kendiniz silebilir veya harici diske tasiyabilirsiniz.' -ForegroundColor DarkGray
    Pause-Menu
}

# --- Optimizasyon ----------------------------------------------------------

function Show-Optimize {
    while ($true) {
        Write-Header 'Optimizasyon araclari'
        Write-Host '1) DNS onbellegini temizle (internet baglanti sorunlarina iyi gelir)'
        Write-Host '2) Surucu optimizasyonu (SSD icin TRIM, HDD icin birlestirme) [yonetici]'
        Write-Host '3) Windows Disk Temizleme aracini ac'
        Write-Host '4) Depolama Algisi (Storage Sense) ayarlarini ac'
        Write-Host '5) Guc planlarini goster'
        Write-Host '0) Geri'
        $c = Read-Host "`nSeciminiz"
        switch ($c) {
            '1' {
                Clear-DnsClientCache -ErrorAction SilentlyContinue
                if (-not $?) { ipconfig /flushdns | Out-Null }
                Write-Log 'DNS onbellegi temizlendi'
                Write-Host 'DNS onbellegi temizlendi.' -ForegroundColor Green; Pause-Menu
            }
            '2' {
                if (-not (Test-Admin)) { Write-Host 'Bu islem icin yonetici olarak calistirin (ana menu 7).' -ForegroundColor Yellow; Pause-Menu; break }
                $vols = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' }
                Write-Host ('Suruculer: ' + (($vols | ForEach-Object { "$($_.DriveLetter):" }) -join ' '))
                if (Confirm-Action 'Tum sabit suruculer optimize edilsin mi? (birkac dakika surebilir)') {
                    foreach ($v in $vols) {
                        Write-Host ("{0}: optimize ediliyor..." -f $v.DriveLetter) -ForegroundColor Cyan
                        Optimize-Volume -DriveLetter $v.DriveLetter -ErrorAction SilentlyContinue
                        Write-Log ("Surucu optimize edildi: {0}:" -f $v.DriveLetter)
                    }
                    Write-Host 'Tamamlandi.' -ForegroundColor Green
                }
                Pause-Menu
            }
            '3' { Start-Process cleanmgr.exe }
            '4' { Start-Process 'ms-settings:storagesense' }
            '5' {
                powercfg /list
                Write-Host "`nPlan degistirmek icin: Denetim Masasi > Guc Secenekleri" -ForegroundColor DarkGray
                Pause-Menu
            }
            '0' { return }
        }
    }
}

function Restart-AsAdmin {
    if (Test-Admin) { Write-Host 'Zaten yonetici olarak calisiyor.' -ForegroundColor Green; Pause-Menu; return }
    if ($IsExe) { Start-Process -FilePath $AppPath -Verb RunAs }
    else { Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$AppPath`"" }
    exit
}

# --- Ana menu ----------------------------------------------------------------

Write-Log "Fast Clear $AppVersion baslatildi"

# Etkilesimsiz tarama: sadece raporu yazar ve cikar (hicbir sey silmez).
if ($ScanOnly) {
    Show-Scan (Invoke-Scan)
    exit 0
}

while ($true) {
    Write-Header "Ana menu  (v$AppVersion)"
    if (Test-Admin) { Write-Host 'Mod: YONETICI' -ForegroundColor Green }
    else { Write-Host 'Mod: standart kullanici (bazi islemler icin 7 ile yonetici olun)' -ForegroundColor DarkYellow }
    Write-Host ''
    Write-Host '1) Sistem ve disk raporu'
    Write-Host '2) Onemsiz dosyalari tara (onizleme, silmez)'
    Write-Host '3) Temizle (secmeli ve onayli)'
    Write-Host '4) Baslangic programlarini listele'
    Write-Host '5) Buyuk dosyalari bul'
    Write-Host '6) Optimizasyon araclari'
    Write-Host '7) Yonetici olarak yeniden baslat'
    Write-Host '0) Cikis'
    switch (Read-Host "`nSeciminiz") {
        '1' { Show-SystemReport }
        '2' { Show-JunkScan }
        '3' { Invoke-Clean; Pause-Menu }
        '4' { Show-Startup }
        '5' { Show-LargeFiles }
        '6' { Show-Optimize }
        '7' { Restart-AsAdmin }
        '0' { Write-Log 'Cikis'; exit }
    }
}
