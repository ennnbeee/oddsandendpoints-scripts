# Location services must be configured in Intune for this to work
# Settings Catalog > Privacy > Let Apps Access Location - Force allow.
# Settings Catalog > System > Allow Location - Force Location On. All Location Privacy settings are toggled on and grayed out. Users cannot change the settings and all consent permissions will be automatically suppressed.
# Enable automatic time zone detection
$registryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$propertyName = 'Start'
# Set the registry value to enable automatic time zone detection
# Restart the Windows Time service to apply the changes
Try {
    Set-ItemProperty -Path $registryPath -Name $propertyName -Value 3
    Restart-Service -Name 'w32time'
    $locationService = Get-Service -Name 'lfsvc'
    if ($locationService.Status -notlike 'Running') {
        Start-Service -Name 'lfsvc'
    }
    Write-Output 'Automatic time zone detection and location services enabled.'
    Exit 0
}
Catch {
    Write-Output 'Error setting Automatic time zone detection and location services.'
    Exit 1
}