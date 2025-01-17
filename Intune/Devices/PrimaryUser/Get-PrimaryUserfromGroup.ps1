[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$groupId,

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String]$appId,

    [Parameter(Mandatory = $false)]
    [String]$appSecret,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Grid', 'CSV')]
    [String]$output = 'Grid',

    [Parameter(Mandatory = $false)]
    [String]$csvPath,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'Group.Read.All,Device.Read.All,DeviceManagementManagedDevices.Read.All,User.Read.All'
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
        $Resource = 'devices'
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
    $Resource = 'deviceManagement/managedDevices'

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
Function Get-MDMGroup() {

    <#
    .SYNOPSIS
    This function is used to get AAD groups using Graph API
    .DESCRIPTION
    The function gets Azure AD groups by searching for the group display name
    .EXAMPLE
    Get-MDMGroup -Name 'SG_MEM'
    Get-MDMGroup -Name 'SG_MEM_Devices_Coporate_POC'
    .NOTES
    NAME: Get-MDMGroup
    #>

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('Name', 'ObjectId')]
        [string]$type,

        [parameter(Mandatory = $true)]
        [string]$value

    )

    $graphApiVersion = 'beta'
    $Resource = 'groups'

    try {
        if ($type -eq 'Name') {
            $searchterm = 'search="displayName:' + $value + '"'
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?$searchterm"
            (Invoke-MgGraphRequest -Uri $uri -Method Get -Headers @{ConsistencyLevel = 'eventual' }).value
        }
        elseif ($type -eq 'ObjectId') {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$value"
            Invoke-MgGraphRequest -Uri $uri -Method Get -Headers @{ConsistencyLevel = 'eventual' }
        }


    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-MDMGroupMembers() {

    <#
    .SYNOPSIS
    This function is used to get AAD groups using Graph API
    .DESCRIPTION
    The function gets Azure AD groups by searching for the group display name
    .EXAMPLE
    Get-MDMGroup -Name 'SG_MEM'
    Get-MDMGroup -Name 'SG_MEM_Devices_Coporate_POC'
    .NOTES
    NAME: Get-MDMGroup
    #>

    [cmdletbinding()]

    param
    (

        [parameter(Mandatory = $true)]
        [string]$groupId

    )

    $graphApiVersion = 'beta'
    $Resource = 'groups'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$groupId/members"

        $graphResults = Invoke-MgGraphRequest -Uri $uri -Method Get -Headers @{ConsistencyLevel = 'eventual' }

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
#endregion Functions

#region testing

$csvPath = 'C:\Source\github\mve-scripts\Intune\Devices\PrimaryUser'
$output = 'Grid'

#endregion testing

#region app auth
Import-Module Microsoft.Graph.Authentication
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

$group = Get-MDMGroup -type ObjectId -value $groupId
Write-Host "Getting group members for $($group.displayName)..." -ForegroundColor Cyan
Write-Host
$groupMembers = Get-MDMGroupMembers -groupId $groupId
Write-Host "Found $($groupMembers.Count) members in Group $($group.displayName)." -ForegroundColor Green
Write-Host

Write-Host 'Getting Intune Managed devices...' -ForegroundColor Cyan
Write-Host
$intuneDevices = Get-ManagedDevices
$optIntuneDevices = @{}
foreach ($itemIntuneDevice in $intuneDevices) {
    $optIntuneDevices[$itemIntuneDevice.azureADDeviceId] = $itemIntuneDevice
}
Write-Host "Found $($intuneDevices.Count) Intune managed devices." -ForegroundColor Green
Write-Host

Write-Host 'Getting Entra ID Users...' -ForegroundColor Cyan
Write-Host
$entraUsers = Get-EntraIDObject -object User
$optEntraUsers = @{}
foreach ($itemEntraUser in $entraUsers) {
    $optEntraUsers[$itemEntraUser.id] = $itemEntraUser
}
Write-Host "Found $($entraUsers.Count) Entra ID users." -ForegroundColor Green
Write-Host

Write-Host "Processing Group $($group.displayName) membership data..." -ForegroundColor Cyan
Write-Host
$membershipReport = @()
foreach ($groupMember in $groupMembers) {

    if ($null -ne $groupMember.deviceId) {
        $deviceIntuneObject = $optIntuneDevices[$groupMember.deviceId]
        if ($null -ne $deviceIntuneObject.userId) {
            $userEntraObject = $optEntraUsers[$deviceIntuneObject.userId]
        }
        else {
            $userEntraObject = $null
        }
    }
    else {
        $deviceIntuneObject = $null
        $userEntraObject = $null
    }

    if ($null -ne $deviceIntuneObject) {
        $memberData = [PSCustomObject]@{
            objectid                     = $groupMember.id
            deviceId                     = $groupMember.deviceId
            deviceDisplayName            = $groupMember.displayName
            deviceOperatingSystem        = $groupMember.operatingSystem
            deviceOperatingSystemVersion = $groupMember.operatingSystemVersion
            deviceOwnership              = $groupMember.deviceOwnership
            deviceSerial                 = $deviceIntuneObject.serialNumber
            userId                       = $userEntraObject.id
            userName                     = $userEntraObject.displayName
            userPrincipalName            = $userEntraObject.userPrincipalName
        }

        $membershipReport += $memberData
    }


}
Write-Host "Finished processing Group $($group.displayName) membership data." -ForegroundColor Green
Write-Host
if ($output -eq 'CSV') {

    while (!$csvPath) {
        $csvPath = Read-Host -Prompt "Please specify a path to export the EPM data to e.g., 'C:\Temp'"
    }
    if (!(Test-Path "$csvPath")) {
        New-Item -ItemType Directory -Path "$csvPath" | Out-Null
    }
    $date = (Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').ToString()
    $csvFile = "$csvPath\GroupMembership_$groupId`_$date.csv"

    # CSV Report
    $membershipReport | Sort-Object ElevationCount -Descending | Export-Csv -Path $csvFile -NoTypeInformation
    Write-Host "Report exported to $csvFile" -ForegroundColor Green
}
elseif ($output -eq 'Grid') {
    $membershipReport | Out-GridView
}
