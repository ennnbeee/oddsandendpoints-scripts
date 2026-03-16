$logs = @()
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/EXE and DLL'; Size = 10MB; CurrentSize = $null }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/MSI and Script'; Size = 10MB; CurrentSize = $null }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/Packaged app-Deployment'; Size = 10MB; CurrentSize = $null }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/Packaged app-Execution'; Size = 10MB; CurrentSize = $null }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-CodeIntegrity/Operational'; Size = 10MB; CurrentSize = $null }

try {
    $remediateCount = 0
    foreach ($log in $logs) {
        $eventLog = Get-WinEvent -ListLog $log.Name -ErrorAction SilentlyContinue
        if ($eventLog) {
            if ($eventLog.MaximumSizeInBytes -ne $log.Size) {
                $remediateCount++
                $log.CurrentSize = $eventLog.MaximumSizeInBytes
            }
        }
        else {
            continue
        }
    }

    if ($remediateCount -gt 0) {
        Write-Output "Remediation needed for $remediateCount event log(s)."
        Write-Output $logs | Format-Table -Property Name, Size, CurrentSize
        exit 1
    }
    else {
        Write-Output 'All event log(s) are configured correctly.'
        exit 0
    }
}
catch {
    Write-Error $_.Exception.Message
    Exit 2000
}