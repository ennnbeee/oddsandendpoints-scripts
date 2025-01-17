[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

)

Function Get-ADEEnrolmentToken() {

    [cmdletbinding()]


    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/depOnboardingSettings'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}
Function Get-ADEEnrolmentProfile() {

    Param(
        [Parameter(Mandatory = $true)]
        $TokenID
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/depOnboardingSettings/$TokenID/enrollmentProfiles"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}
Function Add-ADEEnrolmentProfileAssignment() {

    Param(
        [Parameter(Mandatory = $true)]
        $Id,
        [Parameter(Mandatory = $true)]
        $ProfileID,
        [Parameter(Mandatory = $true)]
        $DeviceSerials
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/depOnboardingSettings/$Id/enrollmentProfiles('$ProfileID')/updateDeviceProfileAssignment"

    $Output = New-Object -TypeName psobject
    $Output | Add-Member -MemberType NoteProperty -Name 'deviceIds' -Value $DeviceSerials
    $JSON = $Output | ConvertTo-Json -Depth 3

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
    }

    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }

}

#region Script
$Sleep = '1'
Write-Host '******************************************************************************'
Write-Host '****    Welcome to the Intune Apple ADE Device Profile Assignment Tool    ****' -ForegroundColor Green
Write-Host '****    This Script will import device serials and assign an ADE profile  ****' -ForegroundColor Cyan
Write-Host '******************************************************************************'
Write-Host
#region authentication
if (Get-MgContext) {
    Write-Host 'Disconnecting from existing Graph session.' -ForegroundColor Cyan
    Disconnect-MgGraph
}
$moduleName = 'Microsoft.Graph'
$Module = Get-InstalledModule -Name $moduleName
if ($Module.count -eq 0) {
    Write-Host "$moduleName module is not available" -ForegroundColor yellow
    $Confirm = Read-Host Are you sure you want to install module? [Y] Yes [N] No
    if ($Confirm -match '[yY]') {
        Install-Module -Name $moduleName -AllowClobber -Scope AllUsers -Force
    }
    else {
        Write-Host "$moduleName module is required. Please install module using 'Install-Module $moduleName -Scope AllUsers -Force' cmdlet." -ForegroundColor Yellow
        break
    }
}
else {
    If ($IsMacOS) {
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId

    }
    ElseIf ($IsWindows) {
        Connect-MgGraph -Scopes $scopes -UseDeviceCode -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
    }
    Else {
        Connect-MgGraph -Scopes $scopes -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
    }

    $graphDetails = Get-MgContext
    if ($null -eq $graphDetails) {
        Write-Host "Not connected to Graph, please review any errors and try to run the script again' cmdlet." -ForegroundColor Red
        break
    }
}
#endregion authentication
Write-Host
$CSVPath = Read-Host 'Please provide the path to the CSV file containing a list of Serial Numbers and ADE Profile Names e.g. C:\temp\ADEDevices.csv'
if (!(Test-Path "$CSVPath")) {
    Write-Host "Import Path for CSV file doesn't exist" -ForegroundColor Red
    Write-Host "Script can't continue" -ForegroundColor Red
    Write-Host
    break
}
Start-Sleep -Seconds $Sleep
Write-Host 'Importing Devices...' -ForegroundColor Cyan
Write-Host
Try {
    $Devices = Import-Csv -Path $CSVPath
    Write-Host 'Imported Device Serials and Assignment Profiles' -ForegroundColor Green
    Write-Host
}
Catch {
    Write-Host 'Unable to Import CSV ' -ForegroundColor Red
    Write-Host
    Break
}
Start-Sleep -Seconds $Sleep
Write-Host 'Processing Enrolment Profiles and Device Serials...' -ForegroundColor Cyan
Write-Host
$DeviceProfiles = @()
foreach ($Device in $Devices) {
    $DeviceProfiles += $Device.EnrolmentProfile
}

$UniqueDeviceProfiles = $DeviceProfiles | Get-Unique
$Assignments = @{}
foreach ($UniqueDeviceProfile in $UniqueDeviceProfiles) {
    $Assignments[$UniqueDeviceProfile] = @()
}
foreach ($Device in $Devices) {
    $Assignments["$($Device.EnrolmentProfile)"] += $Device.Serial
}
Start-Sleep -Seconds $Sleep
Write-Host 'Completed processing Enrolment Profiles and Device Serials' -ForegroundColor Green
Write-Host

Write-Host 'Getting Apple Enrolment Token...' -ForegroundColor Cyan
Write-Host
Try {

    $Token = Get-ADEEnrolmentToken
    Write-Host "Found Token: $($Token.tokenName) in Intune" -ForegroundColor Green
    Write-Host
}
Catch {
    Write-Host 'Unable to retreive the Apple Enrolment Token' -ForegroundColor Red
    Write-Host
    Break
}

Start-Sleep -Seconds $Sleep
foreach ($Assignment in $Assignments.GetEnumerator()) {
    Write-Host 'Preparing to assign Enrolment Profiles to devices...' -ForegroundColor Cyan
    Write-Host
    Write-Host "Enrolment Profile: $($Assignment.Name)" -ForegroundColor Yellow
    Write-Host
    Write-Host "Devices: $($Assignment.Value)" -ForegroundColor Yellow
    Write-Host
    Write-Warning 'Please confirm you are happy to continue assigning the Enrolment Profile to the devices' -WarningAction Inquire
    Try {
        Write-Host 'Assigning Enrolment Profile to devices...' -ForegroundColor Cyan
        Write-Host
        Try {
            $EnrolmentProfile = Get-ADEEnrolmentProfile -TokenID $Token.id | Where-Object { ($_.displayName -eq $Assignment.Name) }
            Try {
                Add-ADEEnrolmentProfileAssignment -TokenID $Token.id -ProfileID $EnrolmentProfile.id -DeviceSerial $Assignment.Value
                Write-Host "Enrolment Profile $($Assignment.Name) successfully assigned to devices: $($Assignment.Value)" -ForegroundColor Green
                Write-Host
                Start-Sleep -Seconds $Sleep
            }
            Catch {
                Write-Host "Unable to assign devices to Enrolment Profile $($Assignment.Name)" -ForegroundColor Red
                Write-Host
            }
        }
        Catch {
            Write-Host "Unable to find Enrolment Profile in Intune with name: $($Assignment.Name)" -ForegroundColor Red
            Write-Host
        }
    }
    Catch {
        Write-Host 'Unable to assign Enrolment Profiles to Devices' -ForegroundColor Red
        Write-Host
    }
}





