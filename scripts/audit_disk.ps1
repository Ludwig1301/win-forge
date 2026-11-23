$ErrorActionPreference = 'SilentlyContinue'

function Get-FolderSizeGB($path) {
    if (-not (Test-Path $path)) { return 0 }
    $out = robocopy $path "NUL" /L /S /XJ /R:0 /W:0 /NFL /NDL /NJH /NC /NS /NP /BYTES 2>$null
    $line = $out | Select-String '^\s*Bytes\s*:\s*(\d+)' | Select-Object -Last 1
    if ($line -and $line.Matches[0].Groups[1].Value) {
        return [math]::Round([double]$line.Matches[0].Groups[1].Value / 1GB, 2)
    }
    return 0
}

Write-Output "=== DRIVE SUMMARY ==="
$drives = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3'
foreach ($d in $drives) {
    $total = [math]::Round($d.Size / 1GB, 2)
    $free = [math]::Round($d.FreeSpace / 1GB, 2)
    $used = [math]::Round(($d.Size - $d.FreeSpace) / 1GB, 2)
    Write-Output "$($d.DeviceID) Used: $used GB / $total GB (Free: $free GB)"
}

foreach ($d in $drives) {
    $root = "$($d.DeviceID)\"
    Write-Output "`n=== $root TOP-LEVEL FOLDERS & FILES (>= 0.1 GB, Junction-Safe) ==="
    Get-ChildItem $root -Force | Where-Object { -not $_.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint) } | ForEach-Object {
        $gb = if ($_.PSIsContainer) { Get-FolderSizeGB $_.FullName } else { [math]::Round($_.Length / 1GB, 2) }
        [PSCustomObject]@{ Name = $_.Name; Type = if ($_.PSIsContainer) { "Dir" } else { "File" }; GB = $gb }
    } | Where-Object { $_.GB -ge 0.1 } | Sort-Object GB -Descending | Format-Table -AutoSize
}

Write-Output "=== KNOWN CLEANABLE CACHES ==="
$caches = @(
    @{ Name = "User Temp"; Path = $env:TEMP },
    @{ Name = "Windows Temp"; Path = "C:\Windows\Temp" },
    @{ Name = "Windows Update DL"; Path = "C:\Windows\SoftwareDistribution\Download" },
    @{ Name = "NuGet cache"; Path = "$env:USERPROFILE\.nuget\packages" },
    @{ Name = "pip cache"; Path = "$env:LOCALAPPDATA\pip\cache" },
    @{ Name = "npm cache"; Path = "$env:LOCALAPPDATA\npm-cache" },
    @{ Name = "HuggingFace cache"; Path = "$env:USERPROFILE\.cache\huggingface\hub" },
    @{ Name = "LM Studio updater"; Path = "$env:LOCALAPPDATA\lm-studio-updater" },
    @{ Name = "Chrome Cache"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" },
    @{ Name = "Edge Cache"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" },
    @{ Name = "CrashDumps"; Path = "$env:LOCALAPPDATA\CrashDumps" }
)
foreach ($c in $caches) {
    if (Test-Path $c.Path) {
        $gb = Get-FolderSizeGB $c.Path
        $mb = [math]::Round($gb * 1024, 1)
        if ($mb -gt 20) { Write-Output "$($c.Name): $mb MB ($($c.Path))" }
    }
}

$sdRecent = Get-ChildItem "C:\Windows\SoftwareDistribution\Download" -Force | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-2) }
if ($sdRecent) {
    Write-Output "[NOTE] SoftwareDistribution\Download has files modified in the last 2 hours (Windows Update may be actively staging)."
}

$hiber = Get-Item "C:\hiberfil.sys" -Force
if ($hiber) { Write-Output "hiberfil.sys: $([math]::Round($hiber.Length / 1GB, 2)) GB" }

$pf = Get-CimInstance Win32_PageFileUsage
if ($pf -and $pf.AllocatedBaseSize -ge 8192) {
    Write-Output "pagefile.sys: Allocated $([math]::Round($pf.AllocatedBaseSize / 1024, 2)) GB | CurrentUsage $([math]::Round($pf.CurrentUsage / 1024, 2)) GB | PeakUsage $([math]::Round($pf.PeakUsage / 1024, 2)) GB"
}

$rbItems = @((New-Object -ComObject Shell.Application).NameSpace(0x0a).Items())
$rb = $rbItems | Measure-Object -Property Size -Sum
Write-Output "Recycle Bin: $([math]::Round($rb.Sum / 1MB, 1)) MB ($($rbItems.Count) items)"
