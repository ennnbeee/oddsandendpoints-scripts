# Load Configuration Manager PowerShell Module
Import-Module ($Env:SMS_ADMIN_UI_PATH.Substring(0, $Env:SMS_ADMIN_UI_PATH.Length - 5) + '\ConfigurationManager.psd1')

# Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-Location $SiteCode":"


# Functions
Function Write-log {

    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        [String]$Path,

        [parameter(Mandatory = $true)]
        [String]$Message,

        [parameter(Mandatory = $true)]
        [String]$Component,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [String]$Type
    )

    switch ($Type) {
        'Info' { [int]$Type = 1 }
        'Warning' { [int]$Type = 2 }
        'Error' { [int]$Type = 3 }
    }

    # Create a log entry
    $Content = "<![LOG[$Message]LOG]!>" + `
        "<time=`"$(Get-Date -Format 'HH:mm:ss.ffffff')`" " + `
        "date=`"$(Get-Date -Format 'M-d-yyyy')`" " + `
        "component=`"$Component`" " + `
        "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + `
        "type=`"$Type`" " + `
        "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " + `
        "file=`"`">"

    # Write the line to the log file
    Add-Content -Path $Path -Value $Content
}

# Log file location same as script
$LogFilePath = Join-Path $PSScriptRoot "$(Get-Date -Format yyyy-MM-dd-HHmm) $($MyInvocation.MyCommand.Name).log"

# Gets all devices without the CCM client that are not servers or inbuilt computer objects
$UnmanagedDevices = Get-CMdevice | Where-Object { ($_.IsClient -eq '') -and ($_.SMSID -notlike '*Unknown Computer*' ) -and ($_.SMSID -notlike '*Provisioning Device*') -and ($_.DeviceOS -notlike '*Server*') }

Foreach ($UnmanagedDevice in $UnmanagedDevices) {
    Try {
        Write-Log -Path $LogFilePath -Message "Attempting to install CCM client on computer $($UnmanagedDevice.Name)" -Component $MyInvocation.MyCommand.Name -Type Info
        Install-CMClient -DeviceId $UnmanagedDevice.ResourceID -AlwaysInstallClient $true -ForceReinstall $true -SiteCode $SiteCode.Name
    }
    Catch {
        Write-Error ($_ | Out-String)
        Write-Log -Path $LogFilePath -Message ($_ | Out-String) -Component $MyInvocation.MyCommand.Name -Type Error
    }

}