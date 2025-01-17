<#
.SYNOPSIS
Allows for a phased and controlled distribution of Windows 11 Feature Updates
following the run and capture of Update Readiness data, tagging devices
in Entra ID with their update readiness risk score for use with Dynamic
Security Groups.

.DESCRIPTION
The Invoke-Windows11Accelerator script allows for the controlled roll out of
Windows 11 Feature Updates based on device readiness risk assessments data.

.PARAMETER tenantId
Provide the Id of the tenant to connect to.

.PARAMETER appId
Provide the Id of the Entra App registration to be used for authentication.

.PARAMETER appSecret
Provide the App secret to allow for authentication to graph

.PARAMETER featureUpdateBuild
Select the Windows 11 Feature Update version you wish to deploy
Choice of 22H2 or 23H2.

.PARAMETER extensionAttribute
Configure the device extensionAttribute to be used for tagging Entra ID objects
with their Feature Update Readiness Assessment risk score.
Choice of 1 to 15

.PARAMETER target
Select the whether you want to target the deployment to groups of users or groups of devices.
Choice of Users or Devices.

.PARAMETER demo
Select whether you want to run the script in demo mode, with this switch it will not tag devices or users with their risk state.

.PARAMETER firstRun
Run the script without with warning prompts, used for continued running of the script.

.PARAMETER scopes
The scopes used to connect to the Graph API using PowerShell.
Default scopes configured are:
'Group.ReadWrite.All,Device.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

.INPUTS
None. You can't pipe objects to Invoke-Windows11AcceleratorUpdate.ps1.

.OUTPUTS
None. Invoke-Windows11AcceleratorUpdate.ps1 doesn't generate any output.

.EXAMPLE
PS> .\Invoke-Windows11AcceleratorUpdate.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -appId 297b3303-da1a-4e58-bdd2-b8d681d1bd71 -appSecret g5m8Q~CSedPeRoee4Ld9Uvg2FhR_0Hy7kUpRIbo -featureUpdateBuild 23H2 -target device -extensionAttribute 15 -demo

.EXAMPLE
PS> .\Invoke-Windows11AcceleratorUpdate.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -appId 297b3303-da1a-4e58-bdd2-b8d681d1bd71 -appSecret g5m8Q~CSedPeRoee4Ld9Uvg2FhR_0Hy7kUpRIbo -featureUpdateBuild 23H2 -target user -extensionAttribute 10 -firstRun $true

#>

[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String]$appId,

    [Parameter(Mandatory = $false)]
    [String]$appSecret,

    [Parameter(Mandatory = $true)]
    [ValidateSet('22H2', '23H2', '24H2')]
    [String]$featureUpdateBuild = '23H2',

    [Parameter(Mandatory = $true)]
    [ValidateSet('user', 'device')]
    [String]$target = 'device',

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 15)]
    [int]$extensionAttribute,

    [Parameter(Mandatory = $false)]
    [String]$scopeTag = 'default',

    [Parameter(Mandatory = $false)]
    [boolean]$firstRun = $true,

    [Parameter(Mandatory = $false)]
    [Switch]$demo,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'Group.ReadWrite.All,Device.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,User.ReadWrite.All,DeviceManagementRBAC.Read.All'
)

#region Functions
Function Connect-ToGraph {
    <#
.SYNOPSIS
Authenticates to the Graph API via the Microsoft.Graph.Authentication module.

.DESCRIPTION
The Connect-ToGraph cmdlet is a wrapper cmdlet that helps authenticate to the Intune Graph API using the Microsoft.Graph.Authentication module. It leverages an Azure AD app ID and app secret for authentication or user-based auth.

.PARAMETER Tenant
Specifies the tenant (e.g. contoso.onmicrosoft.com) to which to authenticate.

.PARAMETER AppId
Specifies the Azure AD app ID (GUID) for the application that will be used to authenticate.

.PARAMETER AppSecret
Specifies the Azure AD app secret corresponding to the app ID that will be used to authenticate.

.PARAMETER Scopes
Specifies the user scopes for interactive authentication.

.EXAMPLE
Connect-ToGraph -tenantId $tenantId -appId $app -appSecret $secret

-#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$tenantId,
        [Parameter(Mandatory = $false)] [string]$appId,
        [Parameter(Mandatory = $false)] [string]$appSecret,
        [Parameter(Mandatory = $false)] [string[]]$scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (Get-Module microsoft.graph.authentication | Select-Object -ExpandProperty Version).major

        if ($AppId -ne '') {
            $body = @{
                grant_type    = 'client_credentials';
                client_id     = $appId;
                client_secret = $appSecret;
                scope         = 'https://graph.microsoft.com/.default';
            }

            $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
            $accessToken = $response.access_token

            if ($version -eq 2) {
                Write-Host 'Version 2 module detected'
                $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                Write-Host 'Version 1 Module Detected'
                Select-MgProfile -Name Beta
                $accesstokenfinal = $accessToken
            }
            $graph = Connect-MgGraph -AccessToken $accesstokenfinal
            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            if ($version -eq 2) {
                Write-Host 'Version 2 module detected'
            }
            else {
                Write-Host 'Version 1 Module Detected'
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $scopes -TenantId $tenantId
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}
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
        $JSON,

        [Parameter()]
        [switch]$csv
    )

    $graphApiVersion = 'Beta'

    if ($csv.IsPresent) {

        $Resource = 'deviceManagement/reports/exportJobs'
    }
    else {
        $Resource = 'deviceManagement/reports/cachedReportConfigurations'
    }

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
        $JSON,

        [Parameter()]
        [switch]$csv

    )

    $graphApiVersion = 'Beta'

    if ($csv.IsPresent) {
        $Resource = "deviceManagement/reports/exportJobs('$Id')"
    }
    elseif ($id) {
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
        $Resource = "users?`$filter=userType eq 'member' and accountEnabled eq true"
    }
    else {
        $Resource = "devices?`$filter=operatingSystem eq 'Windows'"
    }

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get

        $results = @()
        $results += $graphResults.value

        $pages = $graphResults.'@odata.nextLink'
        while ($null -ne $pages) {

            $additional = Invoke-MgGraphRequest -Uri $pages -Method Get

            if ($pages) {
                $pages = $additional.'@odata.nextLink'
            }
            $results += $additional.value
        }
        $results
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
    $Resource = "deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get

        $results = @()
        $results += $graphResults.value

        $pages = $graphResults.'@odata.nextLink'
        while ($null -ne $pages) {

            $additional = Invoke-MgGraphRequest -Uri $pages -Method Get

            if ($pages) {
                $pages = $additional.'@odata.nextLink'
            }
            $results += $additional.value
        }
        $results
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-ScopeTags() {

    [cmdletbinding()]
    param
    (

    )

    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/roleScopeTags'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        (Invoke-MgGraphRequest -Uri $uri -Method Get).value

    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}

#endregion Functions

#region testing
<#
[String[]]$scopes = 'Group.ReadWrite.All,Device.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,User.ReadWrite.All,DeviceManagementRBAC.Read.All'
$scopeTag = 'default'
$featureUpdateBuild = '23H2'
$extensionAttribute = 10
$demo = $true
$firstRun = $true
$target = 'user'
#>
#endregion testing

#region app auth
$graphModule = 'Microsoft.Graph.Authentication'
Write-Host "Checking for $graphModule PowerShell module..." -ForegroundColor Cyan

If (!(Find-Module -Name $graphModule)) {
    Install-Module -Name $graphModule -Scope CurrentUser
}
Write-Host "PowerShell Module $graphModule found." -ForegroundColor Green

if (!([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object FullName -Like "*$graphModule*")) {
    Import-Module -Name $graphModule -Force
}

if (Get-MgContext) {
    Write-Host 'Disconnecting from existing Graph session.' -ForegroundColor Cyan
    Disconnect-MgGraph
}
if ((!$appId -and !$appSecret) -or ($appId -and !$appSecret) -or (!$appId -and $appSecret)) {
    Write-Host 'Missing App Details, connecting using user authentication' -ForegroundColor Yellow
    Connect-ToGraph -tenantId $tenantId -Scopes $scopes
    $existingScopes = (Get-MgContext).Scopes
    Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
    Disconnect-MgGraph
    Write-Host 'Connecting to Graph' -ForegroundColor Cyan
    Connect-ToGraph -tenantId $tenantId -Scopes $existingScopes
}
else {
    Write-Host 'Connecting using App authentication' -ForegroundColor Yellow
    Connect-ToGraph -tenantId $tenantId -appId $appId -appSecret $appSecret
}
#endregion app auth

#region Variables
$ProgressPreference = 'SilentlyContinue';
$rndWait = Get-Random -Minimum 2 -Maximum 5
$extensionAttributeValue = 'extensionAttribute' + $extensionAttribute
$featureUpdate = Switch ($featureUpdateBuild) {
    '22H2' { 'NI22H2' } # Windows 11 22H2 (Nickel)
    '23H2' { 'NI23H2' } # Windows 11 23H2 (Nickel)
    '24H2' { 'GE24H2' } # Windows 11 24H2 (Germanium)
}

#region scope tags
if ($scopeTag -ne 'default') {
    Get-ScopeTags | ForEach-Object {
        if ($_.displayName -eq $scopeTag) {
            $scopeTagId = '{0:d5}' -f [int]$_.id
            $scopeTagId | Out-Null
        }
    }
    if ($null -eq $scopeTagId) {
        Write-Host "Unable to find Scope Tag $scopeTag" -ForegroundColor Red
        Break
    }
}
else {
    $scopeTagId = '00000'
}
#endregion scope tags

$featureUpdateCreate = @"
{
    "reportName": "MEMUpgradeReadinessDevice",
    "filter": "(TargetOS eq '$featureUpdate') and (DeviceScopesTag eq '$scopeTagId')",
    "select": [
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
    "format": "csv",
    "snapshotId": "MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001"
}
"@
#endregion Variables

#region Intro
Write-Host
Start-Sleep -Seconds $rndWait
if ($demo) {
    Write-Host "DEMO: Starting the 'Get Ready for Windows 11' Script..." -ForegroundColor Red
}
else {
    Write-Host "PRODUCTION: Starting the 'Get Ready for Windows 11' Script..." -ForegroundColor Green
}
Write-Host
Write-Host 'The script will carry out the following:' -ForegroundColor Green
Write-Host "    - Capture all Windows Device or User objects from Entra ID, these are used for assigning an Extension Attribute ($extensionAttributeValue) used in the Dynamic Groups." -ForegroundColor White
Write-Host "    - Start a Windows 11 Feature Update Readiness report for your selected build version of $featureUpdateBuild." -ForegroundColor White
Write-Host "    - Capture and process the outcome of the Windows 11 Feature Update Readiness report for build version $featureUpdateBuild" -ForegroundColor White
Write-Host "    - Based on the Risk level for the device, will assign a risk based flag to the Primary User or Device using Extension Attribute $extensionAttributeValue" -ForegroundColor White
Write-Host
Write-Host 'The script can be run multiple times, as the Extension Attributes are overwritten if changed with each run.' -ForegroundColor Cyan
Write-Host
Write-Host "Before proceding with the running of the script, please create Entra ID Dynamic $target Groups for each of the below risk levels, using the provided rule:" -ForegroundColor Green
Write-Host "    - Low Risk: ($target.$extensionAttributeValue -eq ""LowRisk-W11-$featureUpdateBuild"")" -ForegroundColor White
Write-Host "    - Medium Risk: ($target.$extensionAttributeValue -eq ""MediumRisk-W11-$featureUpdateBuild"")" -ForegroundColor White
Write-Host "    - High Risk: ($target.$extensionAttributeValue -eq ""HighRisk-W11-$featureUpdateBuild"")" -ForegroundColor White
Write-Host "    - Not Ready: ($target.$extensionAttributeValue -eq ""NotReady-W11-$featureUpdateBuild"")" -ForegroundColor White
Write-Host "    - Unknown: ($target.$extensionAttributeValue -eq ""Unknown-W11-$featureUpdateBuild"")" -ForegroundColor White
Write-Host
if ($target -eq 'device') {
    Write-Host 'Consider using additional group rules for corporate owned Windows devices such as:' -ForegroundColor Cyan
    Write-Host '(device.deviceOwnership -eq "Company") and (device.deviceOSType -eq "Windows")' -ForegroundColor White
}
else {
    Write-Host 'Consider using additional group rules for Intune license assigned users such as:' -ForegroundColor Cyan
    Write-Host '(user.accountEnabled -eq True) and (user.assignedPlans -any (assignedPlan.servicePlanId -eq "c1ec4a95-1f05-45b3-a911-aa3fa01094f5" -and assignedPlan.capabilityStatus -eq "Enabled"))' -ForegroundColor White
}
Write-Host
if ($firstRun -eq $true) {
    Write-Warning 'Please review the above and confirm you are happy to continue.' -WarningAction Inquire
}
#endregion Intro

#region pre-flight
Write-Host
if ($target -eq 'user') {
    Write-Host 'Getting user objects and associated IDs from Entra ID...' -ForegroundColor Cyan
    $entraUsers = Get-EntraIDObject -object User
    Write-Host "Found $($entraUsers.Count) user objects and associated IDs from Entra ID." -ForegroundColor Green
    if ($entraUsers.Count -eq 0) {
        Write-Host "Found no Users in Entra." -ForegroundColor Red
        Break
    }
    #optimising the entra user data
    $optEntraUsers = @{}
    foreach ($itemEntraUser in $entraUsers) {
        $optEntraUsers[$itemEntraUser.id] = $itemEntraUser
    }
    Write-Host
    Write-Host 'Getting Windows device objects and associated IDs from Microsoft Intune...' -ForegroundColor Cyan
    $intuneDevices = Get-ManagedDevices
    Write-Host "Found $($intuneDevices.Count) Windows device objects and associated IDs from Microsoft Intune." -ForegroundColor Green
    Write-Host
    if ($intuneDevices.Count -eq 0) {
        Write-Host "Found no Windows devices in Intune." -ForegroundColor Red
        Break
    }
    #optimising the intune device data
    $optIntuneDevices = @{}
    foreach ($itemIntuneDevice in $intuneDevices) {
        $optIntuneDevices[$itemIntuneDevice.azureADDeviceId] = $itemIntuneDevice
    }

}
Write-Host 'Getting Windows device objects and associated IDs from Entra ID...' -ForegroundColor Cyan
$entraDevices = Get-EntraIDObject -object Device
Write-Host "Found $($entraDevices.Count) Windows devices and associated IDs from Entra ID." -ForegroundColor Green
if ($entraDevices.Count -eq 0) {
    Write-Host "Found no Windows devices in Entra." -ForegroundColor Red
    Break
}
#optimising the entra device data
$optEntraDevices = @{}
foreach ($itemEntraDevice in $entraDevices) {
    $optEntraDevices[$itemEntraDevice.deviceid] = $itemEntraDevice
}
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
    Write-Host
    Write-Host "Please review the objects reporting as having existing data in the selected attribute $extensionAttributeValue." -ForegroundColor Red
    Write-Warning "If you are happy to overwrite $extensionAttributeValue please continue, otherwise stop the script." -WarningAction Inquire
}
Write-Host "No issues found using the selected attribute $extensionAttributeValue for risk assignment." -ForegroundColor Green
Write-Host
#endregion pre-flight

#region Feature Update Readiness
Write-Host "Starting the Feature Update Readiness Report for Windows 11 $featureUpdateBuild with scope tag $scopeTag..." -ForegroundColor Magenta
Write-Host

$reatureUpdateReport = New-ReportFeatureUpdateReadiness -JSON $featureUpdateCreate -csv
While ((Get-ReportFeatureUpdateReadiness -Id $reatureUpdateReport.id -csv).status -ne 'completed') {
    Write-Host 'Waiting for the Feature Update report to finish processing...' -ForegroundColor Cyan
    Start-Sleep -Seconds $rndWait
}

Write-Host "Windows 11 $featureUpdateBuild feature update readiness completed processing." -ForegroundColor Green
Write-Host
Write-Host "Getting Windows 11 $featureUpdateBuild feature update readiness Report data..." -ForegroundColor Magenta
Write-Host
$csvURL = (Get-ReportFeatureUpdateReadiness -Id $reatureUpdateReport.id -csv).url

$csvHeader = @{Accept = '*/*'; 'accept-encoding' = 'gzip, deflate, br, zstd' }
Add-Type -AssemblyName System.IO.Compression
$csvReportStream = Invoke-WebRequest -Uri $csvURL -Method Get -Headers $csvHeader -UseBasicParsing -ErrorAction Stop -Verbose
$csvReportZip = [System.IO.Compression.ZipArchive]::new([System.IO.MemoryStream]::new($csvReportStream.Content))
$csvReportDevices = [System.IO.StreamReader]::new($csvReportZip.GetEntry($csvReportZip.Entries[0]).open()).ReadToEnd() | ConvertFrom-Csv

if ($($csvReportDevices.Count) -eq 0) {
    Write-Warning 'No Feature Update Readiness report details were found, please review the pre-requisites ' -WarningAction Inquire

}

Write-Host "Found Feature Update Report Details for $($csvReportDevices.Count) devices." -ForegroundColor Green
Write-Host
Write-Host "Processing Windows 11 $featureUpdateBuild feature update readiness Report data for $($csvReportDevices.Count) devices..." -ForegroundColor Magenta

$reportArray = @()
foreach ($csvReportDevice in $csvReportDevices) {

    $riskState = switch ($csvReportDevice.ReadinessStatus) {
        '0' { "LowRisk-W11-$featureUpdateBuild" }
        '1' { "MediumRisk-W11-$featureUpdateBuild" }
        '2' { "HighRisk-W11-$featureUpdateBuild" }
        '3' { "NotReady-W11-$featureUpdateBuild" }
        '5' { "Unknown-W11-$featureUpdateBuild" }
    }

    if ($target -eq 'user') {

        if ($null -ne $csvReportDevice.AadDeviceId) {
            $userObject = $optIntuneDevices[$csvReportDevice.AadDeviceId]

            if ($null -ne $userObject.userId) {
                $userEntraObject = $optEntraUsers[$userObject.userId]
            }
            else {
                $userEntraObject = $null
            }
        }
        else {
            $userObject = $null
            $userEntraObject = $null
        }

        $reportArray += [PSCustomObject]@{
            'AadDeviceId'              = $csvReportDevice.AadDeviceId
            'AppIssuesCount'           = $csvReportDevice.AppIssuesCount
            'AppOtherIssuesCount'      = $csvReportDevice.AppOtherIssuesCount
            'DeviceId'                 = $csvReportDevice.DeviceId
            'DeviceManufacturer'       = $csvReportDevice.DeviceManufacturer
            'DeviceModel'              = $csvReportDevice.DeviceModel
            'DeviceName'               = $csvReportDevice.DeviceName
            'DriverIssuesCount'        = $csvReportDevice.DriverIssuesCount
            'OSVersion'                = $csvReportDevice.OSVersion
            'Ownership'                = $csvReportDevice.Ownership
            'ReadinessStatus'          = $csvReportDevice.ReadinessStatus
            'SystemRequirements'       = $csvReportDevice.SystemRequirements
            'RiskState'                = $riskState
            'userObjectID'             = $userObject.userId
            'userPrincipalName'        = $userObject.userPrincipalName
            "$extensionAttributeValue" = $userEntraObject.onPremisesExtensionAttributes.$extensionAttributeValue
        }

    }
    else {

        if ($null -ne $csvReportDevice.AadDeviceId) {
            $deviceObject = $optEntraDevices[$csvReportDevice.AadDeviceId]
        }
        else {
            $deviceObject = $null
        }

        $reportArray += [PSCustomObject]@{
            'AadDeviceId'              = $csvReportDevice.AadDeviceId
            'AppIssuesCount'           = $csvReportDevice.AppIssuesCount
            'AppOtherIssuesCount'      = $csvReportDevice.AppOtherIssuesCount
            'DeviceId'                 = $csvReportDevice.DeviceId
            'DeviceManufacturer'       = $csvReportDevice.DeviceManufacturer
            'DeviceModel'              = $csvReportDevice.DeviceModel
            'DeviceName'               = $csvReportDevice.DeviceName
            'DriverIssuesCount'        = $csvReportDevice.DriverIssuesCount
            'OSVersion'                = $csvReportDevice.OSVersion
            'Ownership'                = $csvReportDevice.Ownership
            'ReadinessStatus'          = $csvReportDevice.ReadinessStatus
            'SystemRequirements'       = $csvReportDevice.SystemRequirements
            'RiskState'                = $riskState
            'deviceObjectID'           = $deviceObject.id
            "$extensionAttributeValue" = $deviceObject.extensionAttributes.$extensionAttributeValue
        }
    }
}
$reportArray = $reportArray | Sort-Object -Property ReadinessStatus

Write-Host "Processed Windows 11 $featureUpdateBuild feature update readiness data for $($csvReportDevices.Count) devices." -ForegroundColor Green
Write-Host
#endregion Feature Update Readiness

#region Attributes
Write-Host "Starting the assignment of risk based extension attributes to $extensionAttributeValue" -ForegroundColor Magenta
Write-Host
if ($firstRun -eq $true) {
    Write-Warning 'Please confirm you are happy to continue.' -WarningAction Inquire
}
Write-Host
Write-Host "Assigning the Risk attributes to $extensionAttributeValue..." -ForegroundColor cyan
Write-Host
# users are a pain
if ($target -eq 'user') {
    # Removes devices with no primary user
    $userReportArray = $reportArray | Where-Object { $_.userPrincipalName -ne $null -and $_.userPrincipalName -ne '' } | Group-Object userPrincipalName

    foreach ( $user in $userReportArray ) {

        $userObject = $user.Group
        # All user devices at Windows 11
        if (($userObject.ReadinessStatus | Measure-Object -Sum).Sum / $user.count -eq 4) {
            # Only need one device object as they're all Windows 11
            $userObject = $user.Group | Select-Object -First 1

            if ($userObject.$extensionAttributeValue -eq $userObject.RiskState) {
                $riskColour = 'cyan'
                Write-Host "$($userObject.userPrincipalName) risk tag hasn't changed for Windows 11 $featureUpdateBuild" -ForegroundColor White
            }
            else {
                $riskColour = 'Cyan'
                $JSON = @"
                    {
                        "$extAttribute": {
                            "$extensionAttributeValue": "$($userObject.RiskState)"
                        }
                    }
"@
            }

        }
        else {
            # Gets readiness state where not updated to Windows 11, selects highest risk number
            $highestRisk = ($userObject | Where-Object { $_.ReadinessStatus -ne 4 } | Measure-Object -Property ReadinessStatus -Maximum).Maximum
            $userObject = ($userObject | Where-Object { $_.ReadinessStatus -eq $highestRisk } | Select-Object -First 1)

            if ($userObject.$extensionAttributeValue -eq $userObject.RiskState) {
                $riskColour = 'cyan'
                Write-Host "$($userObject.userPrincipalName) risk tag hasn't changed for Windows 11 $featureUpdateBuild" -ForegroundColor White
            }
            else {
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

        If (!$demo) {
            Start-Sleep -Seconds $rndWait
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

        if ($device.$extensionAttributeValue -eq $device.RiskState) {
            Write-Host "$($device.DeviceName) risk tag hasn't changed for Windows 11 $featureUpdateBuild" -ForegroundColor White
        }
        else {
            $JSON = @"
            {
                "$extAttribute": {
                    "$extensionAttributeValue": "$($device.RiskState)"
                }
            }
"@

            # Sleep to stop throttling issues
            If (!$demo) {
                Start-Sleep -Seconds $rndWait
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
}
Write-Host
Write-Host "Completed the assignment of risk based extension attributes to $extensionAttributeValue" -ForegroundColor Green
Write-Host
#endregion Attributes