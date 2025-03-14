# Define the registry key path and value
$registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\MfaRequiredInClipRenew'
$registryValueName = 'Verify Multifactor Authentication in ClipRenew'
$registryValueData = 0  # DWORD value of 0
$sid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-4')
# or SID S-1-5-4 for the interactive group

# Check if the registry key already exists
if (-not (Test-Path -Path $registryPath)) {
    # If the key doesn't exist, create it and set the DWORD value
    New-Item -Path $registryPath -Force | Out-Null
    Set-ItemProperty -Path $registryPath -Name $registryValueName -Value $registryValueData -Type DWORD
    Write-Output 'Registry key created and DWORD value added.'
}
else {
    Write-Output 'Registry key already exists. No changes made.'
}

# Add read permissions for SID (S-1-5-4,interactive users) to the registry key with inheritance
$acl = Get-Acl -Path $registryPath
$ruleSID = New-Object System.Security.AccessControl.RegistryAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($ruleSID)
Set-Acl -Path $registryPath -AclObject $acl
Write-Output "Added 'Interactive' group and SID ($sid) with read permissions (with inheritance) to the registry key."

#Start the scheduledtask
Get-ScheduledTask -TaskName 'LicenseAcquisition' | Start-ScheduledTask
Start-Process "$env:SystemRoot\system32\ClipRenew.exe"