$registryKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles'
$profileNames = @('ennbee*', 'Always On VPN*', 'Corp-WiFi*')
$privateNetworkProfiles = @()

try {
    # Gets all Network Profiles from the registry
    $regNetworkProfiles = Get-ItemProperty -Path $registryKey\* -ErrorAction Stop

    # Loops through all profiles and determines whether the exist in the $profileNames wildcard array
    foreach ($regNetworkProfile in $regNetworkProfiles) {
        $domainNetworkProfiles = $profileNames | Where-Object { $regNetworkProfile.ProfileName -like $_ }

        if (-not $domainNetworkProfiles) {
            $privateNetworkProfiles += $regNetworkProfile
        }
    }

    foreach ($regNetworkProfile in $regNetworkProfiles) {
        # Private Network Profiles
        if ($privateNetworkProfiles.ProfileName -contains $regNetworkProfile.ProfileName) {
            Set-ItemProperty -Path $regNetworkProfile.PSPath -Name 'Category' -Value 1 | Out-Null # Private Profile
        }
        # Domain Network Profiles
        else {
            Set-ItemProperty -Path $regNetworkProfile.PSPath -Name 'Category' -Value 2 | Out-Null # Domain Profile
        }

    }
    Write-Output 'Network Profiles now configured to correction locations.'
    Exit 0
}
catch {
    Write-Output 'Unable to configure Network Profiles.'
    Exit 2000
}