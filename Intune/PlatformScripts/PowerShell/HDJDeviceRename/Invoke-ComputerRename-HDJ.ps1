<#PSScriptInfo
.VERSION 1.1
.GUID 3b42d8c8-cda5-4411-a623-90d812a8e29e
.AUTHOR Michael Niehaus
.Contributor Nick Benton
.COMPANYNAME Microsoft
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
Version 1.0: Initial version.
Version 1.1: Updated version.
.PRIVATEDATA
#>

<#
.DESCRIPTION
 Rename the computer
#>

Param()

#Sets the variables for the customer
$domain = 'ennbee.local' #local domain
$waittime = '60' #sets the restart wait time in minutes


# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne 'ARM64') {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe") {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "$($env:ProgramData)\Microsoft\RenameComputer")) {
    mkdir "$($env:ProgramData)\Microsoft\RenameComputer"
}
Set-Content -Path "$($env:ProgramData)\Microsoft\RenameComputer\RenameComputer.ps1.tag" -Value 'Installed'

# Initialization
$dest = "$($env:ProgramData)\Microsoft\RenameComputer"
if (-not (Test-Path $dest)) {
    mkdir $dest
}
Start-Transcript "$dest\RenameComputer.log" -Append

# Make sure we are already domain-joined
$goodToGo = $true
$details = Get-ComputerInfo
if (-not $details.CsPartOfDomain) {
    Write-Host 'Not part of a domain.'
    $goodToGo = $false
}

# Make sure we have connectivity
$dcInfo = [ADSI]"LDAP://$domain"
if ($null -eq $dcInfo.Path) {
    Write-Host 'No connectivity to the domain.'
    $goodToGo = $false
}

if ($goodToGo) {
    # Get the new computer name
    #$newName = Invoke-RestMethod -Method GET -Uri "https://generatename.azurewebsites.net/api/HttpTrigger1?prefix=AD-"

    #Get serial and removes commas
    $Serial = Get-WmiObject Win32_bios | Select-Object -ExpandProperty SerialNumber
    If (Get-WmiObject -Class win32_battery) {
        $newName = 'L-' + $Serial
    }
    Else {
        $newName = 'D-' + $Serial
    }

    $newName = $newName.Replace(' ', '') #Removes spaces

    #shortens name
    if ($newName.Length -ge 15) {
        $newName = $newName.substring(0, 15)
    }

    # Set the computer name
    Write-Host "Renaming computer to $($newName)"
    Rename-Computer -NewName $newName

    # Remove the scheduled task
    Disable-ScheduledTask -TaskName 'RenameComputer' -ErrorAction Ignore
    Unregister-ScheduledTask -TaskName 'RenameComputer' -Confirm:$false -ErrorAction Ignore
    Write-Host 'Scheduled task unregistered.'

    # Make sure we reboot if still in ESP/OOBE by reporting a 1641 return code (hard reboot)
    if ($details.CsUserName -match 'defaultUser') {
        Write-Host 'Exiting during ESP/OOBE with return code 1641'
        Stop-Transcript
        Exit 1641
    }
    else {
        $waitinseconds = (New-TimeSpan -Minutes $waittime).TotalSeconds
        Write-Host "Initiating a restart in $waitime minutes"
        & shutdown.exe /g /t $waitinseconds /f /c "Restarting the computer in 60 minutes due to a computer name change. Please save your work."
        Stop-Transcript
        Exit 0
    }
}
else {
    # Check to see if already scheduled
    $existingTask = Get-ScheduledTask -TaskName 'RenameComputer' -ErrorAction SilentlyContinue
    if ($null -ne $existingTask) {
        Write-Host 'Scheduled task already exists.'
        Stop-Transcript
        Exit 0
    }

    # Copy myself to a safe place if not already there
    if (-not (Test-Path "$dest\RenameComputer.ps1")) {
        Copy-Item $PSCommandPath "$dest\RenameComputer.PS1"
    }

    # Create the scheduled task action
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-NoProfile -ExecutionPolicy bypass -WindowStyle Hidden -File $dest\RenameComputer.ps1"

    # Create the scheduled task trigger
    $timespan = New-TimeSpan -Minutes 5
    $triggers = @()
    $triggers += New-ScheduledTaskTrigger -Daily -At 9am
    $triggers += New-ScheduledTaskTrigger -AtLogOn -RandomDelay $timespan
    $triggers += New-ScheduledTaskTrigger -AtStartup -RandomDelay $timespan

    # Register the scheduled task
    Register-ScheduledTask -User SYSTEM -Action $action -Trigger $triggers -TaskName 'RenameComputer' -Description 'RenameComputer' -Force -TaskPath 'Intune Helpers'
    Write-Host 'Scheduled task created.'
}

Stop-Transcript