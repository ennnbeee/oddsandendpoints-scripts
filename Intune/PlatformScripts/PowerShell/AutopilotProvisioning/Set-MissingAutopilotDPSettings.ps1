#OOBE Settings
$regSettings = @()
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; name = 'PrivacyConsentStatus'; value = '0'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; name = 'SkipMachineOOBE'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; name = 'ProtectYourPC'; value = '3'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; name = 'SkipUserOOBE'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; name = 'LaunchUserOOBE'; value = '0'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; name = 'DisablePrivacyExperience'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; name = 'DisableVoice'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE'; name = 'HideEULAPage'; value = '1'; type = 'DWord' }
$regSettings += [pscustomobject]@{path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System'; name = 'EnableFirstLogonAnimation'; value = '0'; type = 'DWord' }
#endregion Variables

Try {
    #OOBE
    foreach ($regSetting in $regSettings) {
        New-ItemProperty -Path $($regSetting.path) -Name $($regSetting.name) -Value $($regSetting.value) -PropertyType $($regSetting.type) -Force
    }
    Exit 0
}
Catch {
    Write-Error $_.ErrorDetails
    Exit 1
}
