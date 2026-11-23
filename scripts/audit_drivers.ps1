$ErrorActionPreference = 'SilentlyContinue'

Write-Output "=== HARDWARE & BIOS ==="
Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model | Format-Table -AutoSize
Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion, ReleaseDate | Format-Table -AutoSize

Write-Output "=== KEY SIGNED DRIVERS ==="
Get-CimInstance Win32_PnPSignedDriver | Where-Object {
    $_.DeviceClass -in @('DISPLAY', 'NET', 'MEDIA', 'SCSIAdapter', 'Bluetooth') -and
    $_.DriverVersion -and
    $_.DeviceName -notmatch '^WAN Miniport|^Microsoft Kernel|^Microsoft Wi-Fi|^Bluetooth Device \(Personal|^Generic '
} | Select-Object DeviceClass, DeviceName, DriverVersion, @{N='Date';E={if($_.DriverDate){$_.DriverDate.ToString('yyyy-MM-dd')}}} |
    Sort-Object DeviceClass, DeviceName | Format-Table -AutoSize

Write-Output "=== WINDOWS UPDATE PENDING DRIVERS ==="
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $res = $searcher.Search("IsInstalled=0 and Type='Driver'")
    Write-Output "Pending Windows Update Drivers: $($res.Updates.Count)"
    foreach ($u in $res.Updates) {
        Write-Output "- $($u.Title)"
    }
} catch {
    Write-Output "Windows Update driver search failed: $_"
}
