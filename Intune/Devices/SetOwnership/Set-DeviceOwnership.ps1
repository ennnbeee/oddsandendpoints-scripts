#region Functions
Function Get-ManagedDevices() {

    <#
    .SYNOPSIS
    This function is used to get Intune Managed Devices from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune Managed Device
    .EXAMPLE
    Get-ManagedDevices
    Returns all managed devices but excludes EAS devices registered within the Intune Service
    .EXAMPLE
    Get-ManagedDevices -IncludeEAS
    Returns all managed devices including EAS devices registered within the Intune Service
    .NOTES
    NAME: Get-ManagedDevices
    #>

    [cmdletbinding()]

    param
    (
        [switch]$IncludeEAS,
        [switch]$ExcludeMDM
    )

    # Defining Variables
    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/managedDevices'

    try {

        $Count_Params = 0

        if ($IncludeEAS.IsPresent) { $Count_Params++ }
        if ($ExcludeMDM.IsPresent) { $Count_Params++ }

        if ($Count_Params -gt 1) {

            Write-Warning 'Multiple parameters set, specify a single parameter -IncludeEAS, -ExcludeMDM or no parameter against the function'
            Write-Host
            break

        }

        elseif ($IncludeEAS) {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"

        }

        elseif ($ExcludeMDM) {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=managementAgent eq 'eas'"

        }

        else {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=managementAgent eq 'mdm' and managementAgent eq 'easmdm'"

        }

            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}
Function Set-ManagedDeviceOwnership() {

    [cmdletbinding()]

    param
    (
        $id,
        $ownertype
    )
    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/managedDevices'

    try {

        if ($id -eq '' -or $null -eq $id) {

            Write-Host 'No Device id specified, please provide a device id...' -f Red
            break

        }

        if ($ownerType -eq '' -or $null -eq $ownerType) {

            Write-Host 'No ownerType parameter specified, please provide an ownerType. Supported value personal or company...' -f Red
            Write-Host
            break

        }

        $Output = New-Object -TypeName psobject
        $Output | Add-Member -MemberType NoteProperty -Name 'ownerType' -Value $ownerType

        $JSON = $Output | ConvertTo-Json -Depth 3


        # Send Patch command to Graph to change the ownertype
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$ID"
        Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $Json -ContentType 'application/json'

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}
Function Get-DeviceGroup() {

    [cmdletbinding()]

    param
    (
        [string]$GroupName
    )

    # Defining Variables
    $graphApiVersion = 'v1.0'
    $Resource = 'groups'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=displayName eq '$GroupName'"


            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}
Function Get-DeviceGroupMembers() {

    [cmdletbinding()]

    param
    (
        [string]$id
    )

    # Defining Variables
    $graphApiVersion = 'v1.0'
    $Resource = 'groups'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$id/members"


            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}
#endregion

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

#region Script

Write-Host '****************************************************************************'

Write-Host '****    Welcome to the Endpoint Manager Device Ownership Converter Tool ****' -ForegroundColor Green
Write-Host '****    This Script will change the ownership of devices to Corporate   ****' -ForegroundColor Cyan

Write-Host '****************************************************************************'

Write-Host

Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
Write-Host
Write-Host ' (1) Upload a CSV of device serial numbers to be converted... ' -ForegroundColor Green
Write-Host
Write-Host ' (2) Specify an Azure AD group of devices to be converted... ' -ForegroundColor Green
Write-Host
Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
Write-Host
$Choice_Number = ''
$Choice_Number = Read-Host -Prompt 'Based on which option you want to run, please type 1, 2 or E to exit the script, then hit enter '

while ( !($Choice_Number -eq '1' -or $Choice_Number -eq '2' -or $Choice_Number -eq 'E')) {

    $Choice_Number = Read-Host -Prompt 'Invalid Option, Based on which option you want to run, please type 1, 2 or E to exit the test, then click enter '

}

if ($Choice_Number -eq 'E') {
    Break
}
if ($Choice_Number -eq '1') {
    $CSVPath = Read-Host 'Please provide the path to the CSV file containing a list of device serial numbers e.g. C:\temp\devices.csv'

    if (!(Test-Path "$CSVPath")) {
        Write-Host "Import Path for CSV file doesn't exist" -ForegroundColor Red
        Write-Host "Script can't continue" -ForegroundColor Red
        Write-Host
        break

    }
    else {
        $Devices = Import-Csv -Path $CSVPath
    }
}
if ($Choice_Number -eq '2') {
    $Group = Read-Host 'Please provide the name of the group containing members you want to convert'
    try {
        $id = (Get-DeviceGroup -GroupName "$Group").id

        $Devices = Get-DeviceGroupMembers -id $id
    }
    catch {
        Write-Host 'Unable to find the device group' -ForegroundColor Red
        Write-Host "Script can't continue" -ForegroundColor Red
        Write-Host
        break
    }

}

if (!$Devices) {
    Write-Host 'No devices found, please run the script again...' -ForegroundColor Red
    Write-Host
    Break
}


foreach ($Device in $Devices) {
    If ($Device.SerialNumber) {
        try {
            $ManagedDevice = Get-ManagedDevices | Where-Object { $_.serialnumber -eq $Device.SerialNumber }
            Write-Host 'Found '$ManagedDevice.DeviceName' with ownership '$ManagedDevice.ownerType'' -ForegroundColor Cyan
        }
        catch {
            Write-Host 'Unable to find device with serial number '$Device.SerialNumber'' -ForegroundColor Yellow
        }

    }
    Else {
        try {
            $ManagedDevice = Get-ManagedDevices | Where-Object { $_.azureADDeviceId -eq $Device.deviceId }
            Write-Host 'Found '$ManagedDevice.DeviceName' with ownership '$ManagedDevice.ownerType'' -ForegroundColor Cyan
        }
        catch {
            Write-Host 'Unable to find device with name '$Device.DisplayName'' -ForegroundColor Yellow
        }

    }
    try {
        Set-ManagedDeviceOwnership -id $ManagedDevice.id -ownertype company
        Write-Host 'Device Name: '$ManagedDevice.deviceName' ownership changed from '$ManagedDevice.ownerType' to corporate.' -ForegroundColor Green
    }
    catch {
        Write-Host 'Unable change ownwership of device: '$ManagedDevice.deviceName'' -ForegroundColor Yellow
    }
}

#endregion