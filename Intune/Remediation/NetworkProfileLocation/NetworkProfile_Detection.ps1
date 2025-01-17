#6 - Wired Network, 23 - VPN, 71 - Wireless Network, 243 - Mobile Broadband

$registryKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles'
$profileNames = @('ennbee*', 'Always On VPN*', 'Corp-WiFi*')
$privateNetworkProfiles = @()
$issueNetworkProfiles = @()

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
            if ($regNetworkProfile.Category -ne 1){
                $issueNetworkProfiles += $regNetworkProfile.ProfileName
            }
        }
        # Domain Network Profiles
        else {
            if ($regNetworkProfile.Category -ne 2){
                $issueNetworkProfiles += $regNetworkProfile.ProfileName
            }
        }

    }

    if ($issueNetworkProfiles.count -eq 0) {
        Write-Output 'Network Profiles have correct locations.'
        Exit 0
    }
    else {
        Write-Output 'Network Profiles with misconfigured locations.'
        Exit 1
    }
}
catch {
    Write-Output 'Unable to detect Network Profiles.'
    Exit 2000
}