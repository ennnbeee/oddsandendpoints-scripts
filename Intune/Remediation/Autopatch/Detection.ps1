$transcriptPath = "$env:Programdata\Microsoft\IntuneManagementExtension\Logs"
$transcriptName = 'AutoPatchDetection.log'
New-Item $transcriptPath -ItemType Directory -Force

# stopping orphaned transcripts
try {
    Stop-Transcript | Out-Null
}
catch [System.InvalidOperationException]
{}

Start-Transcript -Path $transcriptPath\$transcriptName -Append

# initialize the array
[PsObject[]]$regKeys = @()
# populate the array with each object
$regKeys += [PsObject]@{ Name = 'DoNotConnectToWindowsUpdateInternetLocations'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
$regKeys += [PsObject]@{ Name = 'DisableWindowsUpdateAccess'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
$regKeys += [PsObject]@{ Name = 'WUServer'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
$regKeys += [PsObject]@{ Name = 'UseWUServer'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' }
$regKeys += [PsObject]@{ Name = 'NoAutoUpdate'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' }

foreach ($setting in $regKeys) {
    Write-Host "checking $($setting.name)"
    if ((Get-Item $setting.path -ErrorAction Ignore).Property -contains $setting.name) {
        Write-Host "$($setting.name) is not correct"
        $remediationNeeded = $true
    }
}

if ($remediationNeeded -eq $true) {
    Write-Host 'Autopatch registry settings are incorrect'
    Stop-Transcript
    exit 1
}
else {
    Write-Host 'Autopatch registry settings are correct'
    Stop-Transcript
    exit 0
}