<#
.SYNOPSIS

.DESCRIPTION
Takes an exported AppLocker policy from XML and creates an Intune custom profile with the corresponding settings.

.PARAMETER tenantId
Provide the Id of the tenant to connect to.

.PARAMETER xmlPath
Path to the XML exported AppLocker policy.

.PARAMETER displayName
Name of the policy to be created in Intune.

.PARAMETER grouping
Name grouping setting for the AppLocker policies.

.PARAMETER enforcement
Configures the AppLocker policy to be in audit or enforce.
Valid set is 'Enforce', 'Audit'

.INPUTS
None. You can't pipe objects to Convert-AppLockerToIntune.ps1.

.OUTPUTS
Convert-AppLockerToIntune.ps1 creates a mobileconfig and plist files in the same folder as the script.

.EXAMPLE
Create an Intune profile called WIN_COPE_AppLocker_Test for AppLocker settings set to Audit, with a grouping of 'Baseline'
PS> .\Convert-AppLockerToIntune.ps1 -tenantId '36019fe7-a342-4d98-9126-1b6f94904ac7' -xmlPath 'C:\Source\github\mve-scripts\Intune\EndpointSecurity\AppLockerConversion\AppLockerRules-Audit.xml' -displayName 'WIN_COPE_AppLocker_Test' -grouping 'Baseline' -enforcement Audit

.EXAMPLE
Create an Intune profile called WIN_COPE_AppLocker_Test for AppLocker settings set to Enforce, with a grouping of 'Development'
PS> .\Convert-AppLockerToIntune.ps1 -tenantId '36019fe7-a342-4d98-9126-1b6f94904ac7' -xmlPath 'C:\Source\github\mve-scripts\Intune\EndpointSecurity\AppLockerConversion\AppLockerRules-Audit.xml' -displayName 'WIN_COPE_AppLocker_Test' -grouping 'Development' -enforcement Enforce

.NOTES
Version:        0.2
Author:         Nick Benton
WWW:            oddsandendpoints.co.uk
Creation Date:  04/09/2025
#>

[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $true)]
    [String]$xmlPath,

    [Parameter(Mandatory = $true)]
    [string]$displayName,

    [Parameter(Mandatory = $true)]
    [string]$grouping,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Enforce', 'Audit')]
    [string]$enforcement


)

<# testing
$tenantId = ''
$xmlPath = 'C:\Source\github\oddsandendpoints-scripts\Intune\EndpointSecurity\AppLockerConversion\broken.xml'
$xmlPath = 'C:\Source\github\oddsandendpoints-scripts\Intune\EndpointSecurity\AppLockerConversion\AppLockerRules-Audit.xml'
$displayName = 'Demo'
$grouping = 'Demo'
$enforcement = 'Audit'
#>

#region variables
[String[]]$scopes = 'DeviceManagementConfiguration.ReadWrite.All'
$grouping = $grouping.Trim() -replace '\s', ''
#endregion variables

#region functions
function Test-JSON() {

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
function Connect-ToGraph {

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

    process {
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
function New-CustomProfile() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON
    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/deviceConfigurations'

    try {
        Test-Json -Json $JSON
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error $_.Exception.Message
        break
    }
}
#endregion functions

#region module check
$modules = @('Microsoft.Graph.Authentication')
foreach ($module in $modules) {
    Write-Host "Checking for $module PowerShell module..." -ForegroundColor Cyan
    Write-Host ''
    if (!(Get-Module -Name $module -ListAvailable)) {
        if ($elevatedStatus -eq $true) {
            Write-Host "PowerShell Module $module not found, installing for all users." -ForegroundColor Yellow
            Write-Host ''
            Install-Module -Name $module -AllowClobber
        }

        else {
            Write-Host "PowerShell Module $module not found, installing for current user." -ForegroundColor Yellow
            Write-Host ''
            Install-Module -Name $module -Scope CurrentUser -AllowClobber
        }

    }
    Write-Host "PowerShell Module $module found." -ForegroundColor Green
    Write-Host ''
    Import-Module -Name $module -Force
}
#endregion module check

#region app auth
try {
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
    $context = Get-MgContext
    Write-Host ''
    Write-Host "Successfully connected to Microsoft Graph tenant with ID $($context.TenantId)." -ForegroundColor Green
}
catch {
    Write-Error $_.Exception.Message
    exit
}
#endregion app auth

try {
    while (!(Test-Path -Path $xmlPath -PathType Leaf)) {
        $xmlPath = Read-Host 'Please enter the path to the AppLocker XML file'
    }
    $dateTime = Get-Date -Format yyyyMMdd-HHmm
    $objectAppLocker = New-Object -TypeName psobject
    $omaSettings = @()
    $xmlFile = Get-ChildItem $xmlPath
    [xml]$xmlDoc = Get-Content $xmlFile

    if ([string]::IsNullOrWhiteSpace($xmlDoc.ChildNodes.RuleCollection)) {
        Write-Error "Provided XML file $xmlPath is not a valid AppLocker export."
        break
    }
    else {
        Write-Host "Found AppLocker Rules in XML file $xmlPath" -ForegroundColor Green
        $ruleCollections = $xmlDoc.ChildNodes.RuleCollection
    }

    foreach ($ruleCollection in $ruleCollections) {
        $objectAppLockerSettings = New-Object -TypeName psobject
        # Sets enforcement mode
        if ($null -ne $ruleCollection.EnforcementMode) {
            if ($enforcement -eq 'Enforce') {
                $ruleCollection.EnforcementMode = 'Enabled'
            }
            else {
                $ruleCollection.EnforcementMode = 'AuditOnly'
            }
            #create separate files for Intune
            [xml]$xmlIntuneSetting = $ruleCollection.OuterXml
            if ($null -ne $($ruleCollection.Type)) {

                $appLockerType = switch ($($ruleCollection.Type)) {
                    'Appx' { 'StoreApps' }
                    'Dll' { 'DLL' }
                    'Exe' { 'EXE' }
                    'Msi' { 'MSI' }
                    'Script' { 'Script' }
                }

                [string]$omaUriValue = $xmlIntuneSetting.RuleCollection.OuterXml
                $omaUri = "./Vendor/MSFT/AppLocker/ApplicationLaunchRestrictions/$grouping/$appLockerType/Policy"

                $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value 'microsoft.graph.omaSettingString'
                $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name 'displayName' -Value $appLockerType
                $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name 'description' -Value $enforcement
                $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name 'omaUri' -Value $omaUri
                $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name 'value' -Value $omaUrivalue
                $omaSettings += $objectAppLockerSettings
            }
        }
    }

    if ($null -ne $omaSettings) {
        $name = $displayName + '-' + $dateTime
        # creates the object with the rules
        $objectAppLocker | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.windows10CustomConfiguration'
        $objectAppLocker | Add-Member -MemberType NoteProperty -Name 'displayName' -Value $name
        $objectAppLocker | Add-Member -MemberType NoteProperty -Name 'description' -Value $null
        $objectAppLocker | Add-Member -MemberType NoteProperty -Name 'omaSettings' -Value @($omaSettings)

        $appLockerJSON = $objectAppLocker | ConvertTo-Json -Depth 5
        Write-Host "Creating AppLocker Custom Profile $name in Intune" -ForegroundColor Cyan
        New-CustomProfile -JSON $appLockerJSON
        Write-Host "Created AppLocker Custom Profile $name in Intune" -ForegroundColor Green
    }
    else {
        Write-Host 'Provided AppLocker export does not contain Rule Collections' -ForegroundColor Red
        break
    }
}
catch {
    Write-Error $_.Exception.Message
    exit
}