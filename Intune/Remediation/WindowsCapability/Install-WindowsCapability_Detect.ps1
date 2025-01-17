$capabilityName = 'VBSCRIPT'

try {
    $windowsCapability = Get-WindowsCapability -online | Where-Object { $_.Name -like "*$capabilityName*" }
    if ($windowsCapability.State  -ne 'Installed') {
        Write-Output "Windows Capability $capabilityName not installed."
        Exit 1
    }
    else {
        Write-Output "Windows Capability $capabilityName installed."
        Exit 0
    }
}
catch {
    Write-Output "Unable to query Windows Capability $capabilityName status."
    Exit 2000
}