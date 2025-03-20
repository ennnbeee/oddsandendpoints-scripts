# Location services must be configured in Intune for this to work
# Settings Catalog > Privacy > Let Apps Access Location - Force allow.
# Settings Catalog > System > Allow Location - Force Location On. All Location Privacy settings are toggled on and grayed out. Users cannot change the settings and all consent permissions will be automatically suppressed.
# Enable automatic time zone detection
$registryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$propertyName = 'Start'
# Check the current registry value
$currentValue = Get-ItemProperty -Path $registryPath -Name $propertyName
try {
    $locationService = Get-Service -Name 'lfsvc'
}
catch {
    Write-Output 'Unable to get location service.'
    Exit 1
}
if ($currentValue.Start -eq 3 -and $locationService.Status -like 'Running') {
    # Set the registry value to enable automatic time zone detection
    Write-Output 'Automatic time zone detection and location services are already enabled.'
    Exit 0
}
else {
    Write-Error 'Automatic time zone detection and location services are not enabled.'
    Exit 2000
}