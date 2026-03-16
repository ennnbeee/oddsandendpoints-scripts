$logs = @()
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/EXE and DLL'; Size = 10MB }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/MSI and Script'; Size = 10MB }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/Packaged app-Deployment'; Size = 10MB }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-AppLocker/Packaged app-Execution'; Size = 10MB }
$logs += [PSCustomObject]@{Name = 'Microsoft-Windows-CodeIntegrity/Operational'; Size = 10MB }

try {
    $remediateCount = 0
    $remediateOutput = @()
    foreach ($log in $logs) {
        $eventLog = Get-WinEvent -ListLog $log.Name -ErrorAction SilentlyContinue
        if ($eventLog) {
            if ($eventLog.MaximumSizeInBytes -ne $log.Size) {
                $remediateCount++
                $remediateOutput += "Event log $($log.Name) is configured with size $($eventLog.MaximumSizeInBytes) bytes, expected size is $($log.Size) bytes"
            }
        }
    }

    if ($remediateCount -gt 0) {
        Write-Output $($remediateOutput -join ", ")
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