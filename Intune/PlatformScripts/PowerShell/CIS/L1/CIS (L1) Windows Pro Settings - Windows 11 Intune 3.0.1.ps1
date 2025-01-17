# Windows Pro Device Settings
$regSettings = @()
$regSettings += [pscustomobject]@{path = 'HKLM:\Software\Policies\Microsoft\Windows\CloudContent'; name = 'DisableWindowsConsumerFeatures'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; name = 'DisableConsumerAccountStateContent'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\Software\Policies\Microsoft\Windows\Appx'; name = 'BlockNonAdminUserInstall'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\Software\Policies\Microsoft\WindowsStore'; name = 'RequirePrivateStoreOnly'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\Software\Policies\Microsoft\Windows\DeviceGuard'; name = 'LsaCfgFlags'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\Software\Policies\Microsoft\Windows\DeviceGuard'; name = 'RequirePlatformSecurityFeatures'; value = '1'; type = 'DWord' }

Try {
    foreach ($regSetting in $regSettings) {
        if (!(Test-Path $($regSetting.path))){
            New-Item -Path $($regSetting.path) -Force
        }
        New-ItemProperty -Path $($regSetting.path) -Name $($regSetting.name) -Value $($regSetting.value) -PropertyType $($regSetting.type) -Force
    }
    Exit 0
}
Catch {
    Write-Error $_.ErrorDetails
    Exit 1
}