Param(
    [Parameter(Mandatory = $false)]
    [switch]
    $ChangePassword,
    [Parameter(Mandatory = $false)]
    [string]
    $OldPassword,
    [Parameter(Mandatory = $true)]
    [string]
    $Password
)

$DetectionRegPath = "HKLM:\SOFTWARE\IntuneHelper\DellBIOSProvider"
$DetectionRegNamePassword = "PasswordSet"

Start-Transcript -Path "$env:TEMP\Set-DellBIOSPassword.log" | Out-Null

if (!(Test-Path -Path $DetectionRegPath)) {
    New-Item -Path $DetectionRegPath -Force | Out-Null
}

if (Test-Path -Path "$env:ProgramFiles\WindowsPowerShell\Modules\DellBIOSProvider") {
    Write-Output "DellBIOSProvider folder already exists @ $env:ProgramFiles\WindowsPowerShell\Modules\DellBIOSProvider."
    Write-Output "Deleting the folder..."
    Remove-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\DellBIOSProvider" -Recurse -Force
}
 
Write-Output "Copying DellBIOSProvider module to: $env:ProgramFiles\WindowsPowerShell\Modules\DellBIOSProvider"
Copy-Item -Path "$ScriptPath\DellBIOSProvider\" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\" -Recurse -Force

try {
    Import-Module "DellBIOSProvider" -Force -Verbose -ErrorAction Stop
    Write-Output "Importing the Dell BIOS Provider module"
}
catch {
    Write-Output "Error importing module: $_"
    exit 1
}

# Set Admin Password if one doesn't exist
$AdminPassSet = (Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet).CurrentValue
if ($AdminPassSet -eq $false) {
    Write-Output "Admin password is not set at this moment, will try to set it."
    Set-Item -Path DellSmbios:\Security\AdminPassword "$Password"
    if ( (Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet).CurrentValue -eq $true ) {
        Write-Output "Admin password has now been set."
        New-ItemProperty -Path "$DetectionRegPath" -Name "$DetectionRegNamePassword" -Value 1 | Out-Null
    }
}

# Change Old Admin Password to new
if ($ChangePassword) {
    Write-Output "Selected to change the Admin password, will try to set it."
    if ($null -eq $OldPassword) {
        Write-Output "`$OldPassword variable has not been specified, will not attempt to change admin password"
        exit 1
    }
    else {
        Write-Output "`$OldPassword variable has been specified, will try to change the admin password"
        Set-Item -Path DellSmbios:\Security\AdminPassword "$Password" -Password "$OldPassword"
        New-ItemProperty -Path "$DetectionRegPath" -Name "$DetectionRegNamePassword" -Value 1 | Out-Null
    }
}

Stop-Transcript