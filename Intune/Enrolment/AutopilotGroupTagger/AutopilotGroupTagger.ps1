<#
.SYNOPSIS


.DESCRIPTION


.EXAMPLE
PS> .\Start-AutopilotGroupTagger.ps1

#>

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
        #Import-Module Microsoft.Graph.Authentication
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
#endregion Functions


#region user variables
# App registration details required for certificate-based authentication
$tenantId = '' # Your tenant ID
$tenantId = '437e8ffb-3030-469a-99da-e5b527908010'
$appId = '' # Enterprise App (Service Principal) App ID
$appSecret = '' # Enterprise App (Service Principal) Secret
#endregion user variables

#region intro
Write-Host '
▄▀█ █░█ ▀█▀ █▀█ █▀█ █ █░░ █▀█ ▀█▀
█▀█ █▄█ ░█░ █▄█ █▀▀ █ █▄▄ █▄█ ░█░
' -ForegroundColor Cyan
Write-Host '
█▀▀ █▀█ █▀█ █░█ █▀█ ▀█▀ ▄▀█ █▀▀ █▀▀ █▀▀ █▀█
█▄█ █▀▄ █▄█ █▄█ █▀▀ ░█░ █▀█ █▄█ █▄█ ██▄ █▀▄
' -ForegroundColor Red

Write-Host 'Autopilot GroupTagger - Update Autopilot Device Group Tags in bulk.' -ForegroundColor Green
Write-Host 'Nick Benton - oddsandendpoints.co.uk' -NoNewline;
Write-Host ' | Version' -NoNewline; Write-Host ' 0.1 Public Preview' -ForegroundColor Yellow -NoNewline
Write-Host ' | Last updated: ' -NoNewline; Write-Host '2025-01-30' -ForegroundColor Magenta
Write-Host ''
Write-Host 'This is a preview version. If you have any feedback, please open an issue at https://github.com/ennnbeee/oddsandendpoints-scripts/issues.' -ForegroundColor Cyan
Write-Host ''
#endregion intro

#region variables
$requiredScopes = @('Device.Read.All', 'DeviceManagementConfiguration.Read.All', 'DeviceManagementManagedDevices.ReadWrite.All', 'DeviceManagementConfiguration.ReadWrite.All')
[String[]]$scopes = $requiredScopes -join ', '
#endregion variables

#region module check
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
    Write-Host 'Disconnected from existing Graph session.' -ForegroundColor Green
}
#endregion module check

#region app auth
if (!$tenantId) {
    Write-Host 'Connecting using interactive authentication' -ForegroundColor Yellow
    Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop
}
else {
    if ((!$appId -and !$appSecret) -or ($appId -and !$appSecret) -or (!$appId -and $appSecret)) {
        Write-Host 'Missing App Details, connecting using user authentication' -ForegroundColor Yellow
        Connect-ToGraph -tenantId $tenantId -Scopes $scopes -ErrorAction Stop
    }
    else {
        Write-Host 'Connecting using App authentication' -ForegroundColor Yellow
        Connect-ToGraph -tenantId $tenantId -appId $appId -appSecret $appSecret -ErrorAction Stop
    }
}
Write-Host 'Successfully connected to Microsoft Graph.' -ForegroundColor Green
#endregion app auth

#region scopes
$context = Get-MgContext
$currentScopes = $context.Scopes

# Validate required permissions
$missingScopes = $requiredScopes | Where-Object { $_ -notin $currentScopes }
if ($missingScopes.Count -gt 0) {
    Write-Host 'WARNING: The following scope permissions are missing:' -ForegroundColor Red
    $missingScopes | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host 'Please ensure these permissions are granted to the app registration for full functionality.' -ForegroundColor Yellow
    exit
}
Write-Host 'All required scope permissions are present.' -ForegroundColor Green
#endregion scopes

#region discovery
Write-Host 'Getting all EntraID computer objects...' -ForegroundColor Cyan
$entraDevices = Get-EntraIDObject -object Device
$entraDevicesOptimised = @{}
foreach ($entraDevice in $entraDevices) {
    $entraDevicesOptimised[$entraDevice.deviceid] = $entraDevice
}
Write-Host "Found $($entraDevices.Count) Windows devices and associated IDs from Entra ID." -ForegroundColor Green

Write-Host 'Getting all Intune Windows devices...' -ForegroundColor Cyan
$intuneDevices = Get-ManagedDevices
$intuneDevicesOptimised = @{}
foreach ($intuneDevice in $intuneDevices) {
    $intuneDevicesOptimised[$intuneDevice.id] = $intuneDevice
}
Write-Host "Found $($intuneDevices.Count) Windows device objects and associated IDs from Microsoft Intune." -ForegroundColor Green


Write-Host 'Getting all Windows Autopilot devices...' -ForegroundColor Cyan
$apDevices = Get-AutopilotDevices
$autopilotDevices = @()
foreach ($apDevice in $apDevices) {
    # Details of Entra ID device object
    $entraObject = $entraDevicesOptimised[$apDevice.azureAdDeviceId]
    # Details of Intune device object
    #$intuneObject = $intuneDevicesOptimised[$apDevice.managedDeviceId]

    $autopilotDevices += [PSCustomObject]@{
        'displayName'      = $entraObject.displayName
        'serialNumber'     = $apDevice.serialNumber
        'manufacturer'     = $apDevice.manufacturer
        'model'            = $apDevice.model
        'enrolmentState'   = $apDevice.enrollmentState
        'enrolmentProfile' = $entraObject.enrollmentProfileName
        'enrolmentType'    = $entraObject.enrollmentType
        'groupTag'         = $apDevice.groupTag
        'Id'               = $apDevice.Id
    }
}
Write-Host "Found $($autopilotDevices.Count) Windows Autopilot Devices from Microsoft Intune." -ForegroundColor Green
#endregion discovery

#region Script
$autopilotUpdateDevicesCount = 0
while ($autopilotUpdateDevicesCount -eq 0) {
    Write-Host
    Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
    Write-Host
    Write-Host ' (1) Update All Autopilot Devices Group Tags' -ForegroundColor Green
    Write-Host
    Write-Host ' (2) Update All Autopilot Devices with Empty Group Tags' -ForegroundColor Green
    Write-Host
    Write-Host ' (3) Update All Autopilot Devices with a specific Group Tag' -ForegroundColor Green
    Write-Host
    Write-Host ' (4) Update a selection of Autopilot Devices Group Tags' -ForegroundColor Green
    Write-Host
    Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
    Write-Host
    $choiceA = ''
    $autopilotUpdateDevices = ''
    $choiceA = Read-Host -Prompt 'Please type 1, 2, 3, 4 or E to exit the script, then press enter'
    while ( $choiceA -notin @('1', '2', '3', '4', 'E')) {
        $choiceA = Read-Host -Prompt 'Please type 1, 2, 3, 4 or E to exit the script, then press enter'
    }
    if ($choiceA -eq 'E') {
        Exit
    }
    if ($choiceA -eq '1') {
        #All AutoPilot Devices
        $autopilotUpdateDevices = $autopilotDevices
    }
    if ($choiceA -eq '2') {
        #All AutoPilot Devices with Empty Group Tags
        $autopilotUpdateDevices = $autopilotDevices | Where-Object { ($null -eq $_.groupTag) -or ($_.groupTag) -eq '' }
    }
    if ($choiceA -eq '3') {
        # Specific Group Tag
        [string]$groupTagOld = Read-Host 'Please enter the group tag you wish to update'
        while ($groupTagOld -eq '' -or $null -eq $groupTagOld) {
            [string]$groupTagOld = Read-Host 'Please enter the group tag you wish to update'
        }
        #All AutoPilot Devices with Specific Group Tag
        $autopilotUpdateDevices = $autopilotDevices | Where-Object { $_.groupTag -eq $groupTagOld }
    }
    if ($choiceA -eq '4') {
        $autopilotUpdateDevices = @($autopilotDevices | Out-GridView -PassThru -Title 'Select Autopilot Devices to Update')
    }
    $autopilotUpdateDevicesCount = $autopilotUpdateDevices.Count
    Write-Host "You have selected $autopilotUpdateDevicesCount Autopilot devices to update." -ForegroundColor Green
}

[string]$groupTagNew = Read-Host "Please enter the NEW group tag you wish to apply to the $autopilotUpdateDevicesCount Autopilot devices"
while ($groupTagNew -eq '' -or $null -eq $groupTagNew) {
    [string]$groupTagNew = Read-Host "Please enter the NEW group tag you wish to apply to the $autopilotUpdateDevicesCount Autopilot devices"
}

Write-Host "The following $autopilotUpdateDevicesCount Autopilot devices are in scope to be updated:" -ForegroundColor Yellow
$autopilotUpdateDevices | Format-Table

Write-Warning -Message "You are about to update the group tag for $autopilotUpdateDevicesCount Autopilot devices to '$groupTagNew'." -WarningAction Inquire

foreach ($autopilotUpdateDevice in $autopilotUpdateDevices) {
    $rndWait = Get-Random -Minimum 0 -Maximum 3
    Write-Host "Updating Autopilot Group Tag with Serial Number: $($autopilotUpdateDevice.serialNumber) to '$groupTagNew'." -ForegroundColor Cyan
    Start-Sleep -Seconds $rndWait
    Set-AutopilotDevice -id $autopilotUpdateDevice.id -groupTag $groupTagNew
    Write-Host "Updated Autopilot Group Tag with Serial Number: $($autopilotUpdateDevice.serialNumber) to '$groupTagNew'." -ForegroundColor Green
}
#endregion Script