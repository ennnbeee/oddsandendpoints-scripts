[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All',

    [Parameter(Mandatory = $true)]
    [ValidateSet('csv', 'online')]
    [string]$method
)

## Functions
Function Get-AutopilotDevices() {

    <#
    .SYNOPSIS
    This function is used to get autopilot devices via the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any autopilot devices
    .EXAMPLE
    Get-AutopilotDevices
    Returns any autopilot devices
    .NOTES
    NAME: Get-AutopilotDevices
    #>

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/windowsAutopilotDeviceIdentities'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}

Function Set-AutopilotDevice() {

    <#
    .SYNOPSIS
    This function is used to set autopilot devices properties via the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and sets autopilot device properties
    .EXAMPLE
    Set-AutopilotDevice
    Returns any autopilot devices
    .NOTES
    NAME: Set-AutopilotDevice
    #>

    [CmdletBinding()]
    param(
        $Id,
        $groupTag
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/windowsAutopilotDeviceIdentities/$Id/updateDeviceProperties"

    try {

        if (!$id) {
            Write-Host 'No Autopilot device Id specified, specify a valid Autopilot device Id' -f Red
            break
        }

        if (!$groupTag) {
            $groupTag = Read-Host 'No Group Tag specified, specify a Group Tag'
        }

        $Autopilot = New-Object -TypeName psobject
        $Autopilot | Add-Member -MemberType NoteProperty -Name 'groupTag' -Value $groupTag

        $JSON = $Autopilot | ConvertTo-Json -Depth 3
        # POST to Graph Service
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
        Write-Host "Successfully added '$groupTag' to device" -ForegroundColor Green

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}

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

# Script Start
# Get Devices
if ($method -eq 'csv') {
    $csvPath = Read-Host 'Please provide the path to the csv file containing a list of device serial numbers and new Group Tag  e.g. C:\temp\devices.csv'

    if (!(Test-Path "$csvPath")) {
        Write-Host "Import Path for csv file doesn't exist" -ForegroundColor Red
        Write-Host "Script can't continue" -ForegroundColor Red
        Write-Host
        break

    }
    else {
        $autopilotDevices = Import-Csv -Path $csvPath
    }
}
else {
    Write-Host 'Getting all Autopilot devices without a Group Tag' -ForegroundColor Cyan
    $autopilotDevices = Get-AutopilotDevices | Where-Object { ($null -eq $_.groupTag) -or ($_.groupTag) -eq '' }
    $groupTag = Read-Host "Please enter the default group tag for devices without a tag"
}

# Sets Group Tag
foreach ($autopilotDevice in $autopilotDevices) {

    $id = $autopilotDevice.id
    if (!$id) {
        Write-Host 'No Autopilot Device Id, getting Id from Graph' -ForegroundColor Cyan
        $id = (Get-AutopilotDevices | Where-Object { ($_.serialNumber -eq $autopilotDevice.'serial Number') }).id
        Write-Host "ID:'$Id' found for device with serial '$($autopilotDevice.'Serial number')'" -ForegroundColor Green
    }

    if ($method -eq 'csv') {
        $groupTag = $autopilotDevice.'group Tag'
        if (!$groupTag) {
            Write-Host 'No Autopilot Device Group Tag found in csv' -ForegroundColor Cyan
            $groupTag = Read-Host "Please enter the group tag for device with serial $($autopilotDevice.'serial Number') now"
        }
    }

    try {
        Set-AutopilotDevice -id $id -groupTag $groupTag
        Write-Host "Group tag: '$groupTag' set for device with serial $($autopilotDevice.'Serial number')" -ForegroundColor Green
    }
    catch {
        Write-Host "Group tag: '$groupTag' not set for device with serial $($autopilotDevice.'Serial number')" -ForegroundColor Red
    }
}