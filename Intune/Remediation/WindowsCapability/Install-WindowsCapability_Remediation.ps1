$capabilityName = 'VBSCRIPT'

Try {
    Get-WindowsCapability -online | Where-Object { $_.Name -like "*$capabilityName*" } | Add-WindowsCapability -Online
    Exit 0
}
Catch {
    Write-Output "Unable to install Windows Capability $capabilityName status."
    Exit 2000
}