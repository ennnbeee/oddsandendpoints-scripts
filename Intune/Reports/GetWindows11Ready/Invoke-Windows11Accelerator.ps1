<#
.SYNOPSIS
Allows for a phased and controlled distribution of Windows 11 Feature Updates
following the run and capture of Update Readiness data, tagging devices
in Entra ID with their update readiness risk score for use with Dynamic
Security Groups.

.DESCRIPTION
The Invoke-Windows11Accelerator script allows for the controlled roll out of
Windows 11 Feature Updates based on device readiness risk assements data.

.PARAMETER tenantId
Provide the Id of the tenant to connecto to.

.PARAMETER featureUpdateBuild
Select the Windows 11 Feature Update verion you wish to deploy
Choice of 22H2 or 23H2.

.PARAMETER extensionAttribute
Configure the device extensionAttribute to be used for tagging Entra ID objects
with their Feature Update Readiness Assessment risk score.
Choice of 1 to 15

.PARAMETER target
Select the whether you want to target the deployment to groups of users or groups of devices.
Choice of Users or Devices.

.PARAMETER scopes
The scopes used to connect to the Graph API using PowerShell.
Default scopes configured are:
'Group.ReadWrite.All,Device.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

.PARAMETER deploy
Select whether you want to run the script, with this switch it will tag devices or users with their risk state, without it the script will run in report only mode.

.INPUTS
None. You can't pipe objects to Invoke-Windows11Accelerator.

.OUTPUTS
None. Invoke-Windows11Accelerator doesn't generate any output.

.EXAMPLE
PS> .\Invoke-Windows11Accelerator.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -featureUpdateBuild 23H2 -target Devices -extensionAttribute 15

.EXAMPLE
PS> .\Invoke-Windows11Accelerator.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -featureUpdateBuild 22H2 -target Users -extensionAttribute 10

#>

[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('22H2', '23H2')]
    [String]$featureUpdateBuild = '23H2',

    [Parameter(Mandatory = $false)]
    [ValidateSet('user', 'device')]
    [String]$target = 'device',

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 15)]
    [String]$extensionAttribute,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'Group.ReadWrite.All,Device.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,User.ReadWrite.All',

    [Parameter(Mandatory = $false)]
    [Switch]$deploy

)

#region Functions
Function Test-JSON() {

    param (
        $JSON
    )

    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
        $TestJSON | Out-Null
        $validJson = $true
    }
    catch {
        $validJson = $false
        $_.Exception
    }
    if (!$validJson) {
        Write-Host "Provided JSON isn't in valid JSON format" -f Red
        break
    }

}
Function New-ReportFeatureUpdateReadiness() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON
    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/reports/cachedReportConfigurations'

    try {
        Test-Json -Json $JSON
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-ReportFeatureUpdateReadiness() {

    [cmdletbinding()]

    param (

        [parameter(Mandatory = $false)]
        $Id,

        [parameter(Mandatory = $false)]
        $JSON

    )

    $graphApiVersion = 'Beta'

    if ($id) {
        $Resource = "deviceManagement/reports/cachedReportConfigurations('$Id')"
    }
    elseif ($JSON) {
        $Resource = 'deviceManagement/reports/getCachedReport'
    }

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        if ($id) {
            Invoke-MgGraphRequest -Uri $uri -Method Get
        }
        elseif ($JSON) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json' -OutputFilePath $tempFile
            Get-Content -Raw $tempFile | ConvertFrom-Json
            Remove-Item $tempFile
        }

    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-ObjectAttribute() {

    [cmdletbinding()]

    param
    (

        [parameter(Mandatory = $true)]
        [ValidateSet('User', 'Device')]
        $object,

        [parameter(Mandatory = $true)]
        $JSON,

        [parameter(Mandatory = $true)]
        $Id
    )

    $graphApiVersion = 'Beta'
    if ($object -eq 'User') {
        $Resource = "users/$Id"
    }
    else {
        $Resource = "devices/$Id"
    }

    try {
        Test-Json -Json $JSON
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-EntraIDObject() {

    [cmdletbinding()]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateSet('User', 'Device')]
        $object

    )

    $graphApiVersion = 'beta'
    if ($object -eq 'User') {
        $Resource = 'users'
    }
    else {
        $Resource = 'devices'
    }

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $GraphResults = Invoke-MgGraphRequest -Uri $uri -Method Get

        $Results = @()
        $Results += $GraphResults.value

        $Pages = $GraphResults.'@odata.nextLink'
        while ($null -ne $Pages) {

            $Additional = Invoke-MgGraphRequest -Uri $Pages -Method Get

            if ($Pages) {
                $Pages = $Additional.'@odata.nextLink'
            }
            $Results += $Additional.value
        }
        $Results
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}

Function Get-ManagedDevices() {

    [cmdletbinding()]
    param
    (

    )

    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/managedDevices'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $GraphResults = Invoke-MgGraphRequest -Uri $uri -Method Get

        $Results = @()
        $Results += $GraphResults.value

        $Pages = $GraphResults.'@odata.nextLink'
        while ($null -ne $Pages) {

            $Additional = Invoke-MgGraphRequest -Uri $Pages -Method Get

            if ($Pages) {
                $Pages = $Additional.'@odata.nextLink'
            }
            $Results += $Additional.value
        }
        $Results
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}

#endregion Functions

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
        Connect-MgGraph -Scopes $scopes -TenantId $tenantId
    }

    $graphDetails = Get-MgContext
    if ($null -eq $graphDetails) {
        Write-Host "Not connected to Graph, please review any errors and try to run the script again' cmdlet." -ForegroundColor Red
        break
    }
}
#endregion authentication

#region Variables
$ProgressPreference = 'SilentlyContinue';
$rndWait = Get-Random -Minimum 1 -Maximum 5
$extensionAttributeValue = 'extensionAttribute' + $extensionAttribute
$fu = Switch ($featureUpdateBuild) {
    '22H2' { 'NI22H2' }
    '23H2' { 'NI23H2' }
    '24H2' { 'NI24H2' }
}
$featureUpdateCreateJSON = @"
{
    "id": "MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001",
    "filter": "(TargetOS eq '$fu') and (DeviceScopesTag eq '00000')",
    "orderBy": [],
    "select": [
        "DeviceName",
        "DeviceManufacturer",
        "DeviceModel",
        "OSVersion",
        "ReadinessStatus",
        "SystemRequirements",
        "AppIssuesCount",
        "DriverIssuesCount",
        "AppOtherIssuesCount"
    ],
    "metadata": "TargetOS=>filterPicker=V2luZG93cyUyMDExJTIwLSUyMHZlcnNpb24lMjAyMkgy,DeviceScopesTag=>filterPicker=RGVmYXVsdA=="
}
"@

$featureUpdateGetJSON = @'
{
    "Id": "MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001",
    "Skip": 0,
    "Top": 50,
    "Search": "",
    "OrderBy": [],
    "Select": [
        "DeviceName",
        "DeviceManufacturer",
        "DeviceModel",
        "OSVersion",
        "ReadinessStatus",
        "SystemRequirements",
        "AppIssuesCount",
        "DriverIssuesCount",
        "AppOtherIssuesCount",
        "DeviceId",
        "AadDeviceId",
        "Ownership"
    ],
    "filter": ""
}
'@
#endregion Variables

#region Intro
Write-Host
Start-Sleep -Seconds $rndWait
Write-Host
if ($deploy) {
    Write-Host "Starting the 'Get Ready for Windows 11' Script..." -ForegroundColor Red
    Write-Host
}
else {
    Write-Host "Starting the 'Get Ready for Windows 11' Script in demo mode..." -ForegroundColor Magenta
    Write-Host
}
Write-Host 'The script will carry out the following:' -ForegroundColor Green
Write-Host "    - Capture all Windows Device or User objects from Entra ID, these are used for assigning an Extension Attribute ($extensionAttributeValue) used in the Dynamic Groups." -ForegroundColor White
Write-Host "    - Start a Windows 11 Feature Update Readiness report for your selected build version of $featureUpdateBuild." -ForegroundColor White
Write-Host "    - Capture and process the outcome of the Windows 11 Feature Update Readiness report for build version $featureUpdateBuild" -ForegroundColor White
Write-Host "    - Based on the Risk level for the device, will assign a risk based flag to the Primary User or Device using Extension Attribute $extensionAttributeValue" -ForegroundColor White
Write-Host
Write-Host 'The script can be run multiple times, as the Extension Attributes are overwritten with each run.' -ForegroundColor Cyan
Write-Host
Write-Host "Before proceding with the running of the script, please create Entra ID Dynamic $target Groups for each of the below risk levels, using the provided rule:" -ForegroundColor Green
Write-Host "    - Low Risk: ($target.$extensionAttributeValue -eq"LowRisk-W11-$featureUpdateBuild")" -ForegroundColor White
Write-Host "    - Medium Risk: ($target.$extensionAttributeValue -eq"MediumRisk-W11-$featureUpdateBuild")" -ForegroundColor White
Write-Host "    - High Risk: ($target.$extensionAttributeValue -eq"HighRisk-W11-$featureUpdateBuild")" -ForegroundColor White
Write-Host "    - Not Ready: ($target.$extensionAttributeValue -eq"NotReady-W11-$featureUpdateBuild")" -ForegroundColor White
Write-Host "    - Unknown: ($target.$extensionAttributeValue -eq"Unknown-W11-$featureUpdateBuild")" -ForegroundColor White
Write-Host
Write-Warning 'Please review the above and confirm you are happy to continue.' -WarningAction Inquire
#endregion Intro

#region pre-flight
Write-Host
if ($target -eq 'user') {
    Write-Host 'Getting user objects and associated IDs from Entra ID...' -ForegroundColor Cyan
    $entraUsers = Get-EntraIDObject -object User | Where-Object { $_.accountEnabled -eq 'true' -and $_.userType -eq 'Member' }
    Write-Host "Found $($entraUsers.Count) user objects and associated IDs from Entra ID." -ForegroundColor Green
    Write-Host
    Write-Host 'Getting device objects and associated IDs from Microsoft Intune...' -ForegroundColor Cyan
    $intuneDevices = Get-ManagedDevices | Where-Object { $_.operatingSystem -eq 'Windows' }
    Write-Host "Found $($intuneDevices.Count) device objects and associated IDs from Microsoft Intune." -ForegroundColor Green
    Write-Host
}
Write-Host 'Getting device objects and associated IDs from Entra ID...' -ForegroundColor Cyan
$entraDevices = Get-EntraIDObject -object Device | Where-Object { $_.operatingSystem -eq 'Windows' }
Write-Host "Found $($entraDevices.Count) Windows devices and associated IDs from Entra ID." -ForegroundColor Green
Write-Host
Write-Host "Checking for existing data in attribute $extensionAttributeValue in Entra ID..." -ForegroundColor Cyan

$attributeErrors = 0
$safeAttributes = @("LowRisk-W11-$featureUpdateBuild", "MediumRisk-W11-$featureUpdateBuild", "HighRisk-W11-$featureUpdateBuild", "NotReady-W11-$featureUpdateBuild", "Unknown-W11-$featureUpdateBuild")

$entraObjects = switch ($target) {
    'user' { $entraUsers }
    'device' { $entraDevices }
}

$extAttribute = switch ($target) {
    'user' { 'onPremisesExtensionAttributes' }
    'device' { 'extensionAttributes' }
}

foreach ($entraObject in $entraObjects) {

    $attribute = ($entraObject.$extAttribute | ConvertTo-Json | ConvertFrom-Json).$extensionAttributeValue

    if ($attribute -notin $safeAttributes) {
        if ($null -ne $attribute) {
            Write-Host "$($entraObject.displayName) already has a value of '$attribute' configured in $extensionAttributeValue" -ForegroundColor Yellow
            $attributeErrors = $attributeErrors + 1
        }
    }
}
if ($attributeErrors -gt 0) {
    Write-Host "Please review the objects reporting as having existing data in the selected attribute $extensionAttributeValue." -ForegroundColor Red
    Write-Warning "If you are happy to overwrite $extensionAttributeValue please continue, otherwise stop the script." -WarningAction Inquire
}
Write-Host "No issues found using the selected attribute $extensionAttributeValue for risk assignment." -ForegroundColor Green
Write-Host
#endregion pre-flight

#region Feature Update Readiness
Write-Host "Starting the Feature Update Readiness Report for Windows 11 $featureUpdateBuild..." -ForegroundColor Magenta
Write-Host

$startFeatureUpdateReport = New-ReportFeatureUpdateReadiness -JSON $featureUpdateCreateJSON
While ((Get-ReportFeatureUpdateReadiness -Id $startFeatureUpdateReport.id).status -ne 'completed') {
    Write-Host 'Waiting for the Feature Update report to finish processing...' -ForegroundColor Cyan
    Start-Sleep -Seconds $rndWait

}
Write-Host 'Feature Update Readiness report completed processing.' -ForegroundColor Green
Write-Host
Write-Host 'Getting Feature Update Report data...' -ForegroundColor Magenta
Write-Host

$featureUpdateReport = Get-ReportFeatureUpdateReadiness -JSON $featureUpdateGetJSON

Write-Host "Found Feature Update Report Details for $($featureUpdateReport.TotalRowCount) devices." -ForegroundColor Green
Write-Host
Write-Host "Processing data for 0 out of $($featureUpdateReport.TotalRowCount) devices..." -ForegroundColor Cyan
$featureUpdateReportDetails = @()
$featureUpdateReportDetails += $featureUpdateReport.Values

$i = 0
if ($($featureUpdateReport.TotalRowCount) -gt 50) {
    while ($i -le $($featureUpdateReport.TotalRowCount)) {
        $i = $i + 50
        $getNextJSON = @"
    {
        "Id": "MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001",
        "Skip": $i,
        "Top": 50,
        "Search": "",
        "OrderBy": [],
        "Select": [
            "DeviceName",
            "DeviceManufacturer",
            "DeviceModel",
            "OSVersion",
            "ReadinessStatus",
            "SystemRequirements",
            "AppIssuesCount",
            "DriverIssuesCount",
            "AppOtherIssuesCount",
            "DeviceId",
            "AadDeviceId",
            "Ownership"
        ],
        "filter": ""
    }
"@
        # Sleep to stop throttling issues
        Start-Sleep -Seconds $rndWait
        $featureUpdateReportNext = Get-ReportFeatureUpdateReadiness -JSON $getNextJSON
        Write-Host "Processing data for $i out of $($featureUpdateReport.TotalRowCount) devices..." -ForegroundColor Cyan
        $featureUpdateReportDetails += $featureUpdateReportNext.Values
    }
}
Write-Host "Processed data for $($featureUpdateReport.TotalRowCount) devices..." -ForegroundColor Green
Write-Host

Write-Host "Processing Windows 11 $featureUpdateBuild feature update readiness data for $($featureUpdateReport.TotalRowCount) devices..." -ForegroundColor Cyan
Write-Host

$reportArray = @()
foreach ($featureUpdateReportEntry in $featureUpdateReportDetails) {

    $riskState = switch ($featureUpdateReportEntry[10]) {
        '0' { "LowRisk-W11-$featureUpdateBuild" }
        '1' { "MediumRisk-W11-$featureUpdateBuild" }
        '2' { "HighRisk-W11-$featureUpdateBuild" }
        '3' { "NotReady-W11-$featureUpdateBuild" }
        '5' { "Unknown-W11-$featureUpdateBuild" }
    }

    $reportArray += [PSCustomObject]@{
        'AadDeviceId'         = $featureUpdateReportEntry[0]
        'AppIssuesCount'      = $featureUpdateReportEntry[1]
        'AppOtherIssuesCount' = $featureUpdateReportEntry[2]
        'DeviceId'            = $featureUpdateReportEntry[3]
        'DeviceManufacturer'  = $featureUpdateReportEntry[4]
        'DeviceModel'         = $featureUpdateReportEntry[5]
        'DeviceName'          = $featureUpdateReportEntry[6]
        'DriverIssuesCount'   = $featureUpdateReportEntry[7]
        'OSVersion'           = $featureUpdateReportEntry[8]
        'Ownership'           = $featureUpdateReportEntry[9]
        'ReadinessStatus'     = $featureUpdateReportEntry[10]
        'SystemRequirements'  = $featureUpdateReportEntry[11]
        'RiskState'           = $riskState
        'deviceObjectID'      = $(($entraDevices | Where-Object { $_.deviceid -eq $featureUpdateReportEntry[0] }).id)
        'userObjectID'        = $(($intuneDevices | Where-Object { $_.azureActiveDirectoryDeviceId -eq $featureUpdateReportEntry[0] }).userId)
        'userPrincipalName'   = $(($intuneDevices | Where-Object { $_.azureActiveDirectoryDeviceId -eq $featureUpdateReportEntry[0] }).userPrincipalName)
    }
}
$reportArray = $reportArray | Sort-Object -Property ReadinessStatus -Descending

Write-Host "Processed Windows 11 $featureUpdateBuild feature update readiness data for $($featureUpdateReport.TotalRowCount) devices." -ForegroundColor Green
Write-Host
#endregion Feature Update Readiness

#region Attributes
Write-Host "Starting the assignment of risk based extension attributes to $extensionAttributeValue" -ForegroundColor Magenta
Write-Host
Write-Warning 'Please confirm you are happy to continue.' -WarningAction Inquire
Write-Host
Write-Host "Assigning the Risk attributes to $extensionAttributeValue..." -ForegroundColor cyan
Write-Host
# users are a pain
if ($target -eq 'user') {
    # Removes devices with no primary user
    $userReportArray = $reportArray | Where-Object { $_.userPrincipalName -ne $null -and $_.userPrincipalName -ne '' } | Group-Object userPrincipalName

    foreach ( $user in $userReportArray ) {

        Start-Sleep -Seconds $rndWait
        # one device for a user
        if ($user.count -eq 1) {
            $userObject = $user.Group
            $riskColour = switch ($($userObject.ReadinessStatus)) {
                '0' { 'Green' }
                '1' { 'Yellow' }
                '2' { 'Red' }
                '3' { 'Red' }
                '4' { 'Cyan' }
                '5' { 'Magenta' }
            }

            $JSON = @"
            {
                "$extAttribute": {
                    "$extensionAttributeValue": "$($userObject.RiskState)"
                }
            }
"@
        }
        # Multiple devices for a user
        else {
            $userObject = $user.Group
            # All user devices at Windows 11
            if (($userObject.ReadinessStatus | Measure-Object -Sum).Sum / $user.count -eq 4) {
                # Only need one device object as they're all Windows 11
                $userObject = $user.Group | Select-Object -First 1
                $riskColour = 'Cyan'
                $JSON = @"
                {
                    "$extAttribute": {
                        "$extensionAttributeValue": "$($userObject.RiskState)"
                    }
                }
"@
            }
            else {
                # Gets readiness state where not updated to Windows 11, selects highest risk number
                $highestRisk = ($user.Group | Where-Object { $_.ReadinessStatus -ne 4 } | Measure-Object -Property ReadinessStatus -Maximum).Maximum
                $userObject = ($user.Group | Where-Object { $_.ReadinessStatus -eq $highestRisk } | Select-Object -First 1)
                $riskColour = switch ($($userObject.ReadinessStatus)) {
                    '0' { 'Green' }
                    '1' { 'Yellow' }
                    '2' { 'Red' }
                    '3' { 'Red' }
                    '4' { 'Cyan' }
                    '5' { 'Magenta' }
                }
                $JSON = @"
                {
                    "$extAttribute": {
                        "$extensionAttributeValue": "$($userObject.RiskState)"
                    }
                }
"@

            }


        }

        If ($deploy) {
            Add-ObjectAttribute -object User -Id $($userObject.userObjectID) -JSON $JSON
        }
        if ($($user.Group.ReadinessStatus) -eq 4) {
            Write-Host "$($userObject.userPrincipalName) $extensionAttributeValue risk tag removed as already updated to Windows 11 $featureUpdateBuild" -ForegroundColor $riskColour
        }
        else {
            Write-Host "$($userObject.userPrincipalName) assigned risk tag $($userObject.RiskState) to $extensionAttributeValue for Windows 11 $featureUpdateBuild" -ForegroundColor $riskColour
        }

    }
}
# devices
else {
    Foreach ($device in $reportArray) {

        $JSON = @"
            {
                "$extAttribute": {
                    "$extensionAttributeValue": "$($device.RiskState)"
                }
            }
"@

        # Sleep to stop throttling issues
        Start-Sleep -Seconds $rndWait
        If ($deploy) {
            Add-ObjectAttribute -object Device -Id $device.deviceObjectID -JSON $JSON
        }

        $riskColour = switch ($($device.ReadinessStatus)) {
            '0' { 'Green' }
            '1' { 'Yellow' }
            '2' { 'Red' }
            '3' { 'Red' }
            '4' { 'Cyan' }
            '5' { 'Magenta' }
        }
        if ($($device.ReadinessStatus) -eq 4) {
            Write-Host "$($device.DeviceName) $extensionAttributeValue risk tag removed as already updated to Windows 11 $featureUpdateBuild" -ForegroundColor $riskColour
        }
        else {
            Write-Host "$($device.DeviceName) assigned risk tag $($device.RiskState) to $extensionAttributeValue for Windows 11 $featureUpdateBuild" -ForegroundColor $riskColour
        }
    }
}

Write-Host
Write-Host "Completed the assignment of risk based extension attributes to $extensionAttributeValue" -ForegroundColor Green
Write-Host
#endregion  Attributes

#Disconnect-MgGraph