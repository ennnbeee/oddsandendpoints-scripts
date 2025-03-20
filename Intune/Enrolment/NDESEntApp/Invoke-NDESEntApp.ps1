<#
Author -    Chris Sellar
Date -      07/03/2025
Purpose -   Create NDES App Proxy, Connector Group and Assign to App

Notes

This script is still in Test and should not be used in production environments.

#>

[CmdletBinding(DefaultParameterSetName = 'Default')]

param(

    [Parameter(Mandatory = $true)]
    [String]$appName,

    [Parameter(Mandatory = $true)]
    [String]$internalServerName,

    [Parameter(Mandatory = $true)]
    [String]$externalServerName,

    [Parameter(Mandatory = $true)]
    [String]$connectorGroupName

)

#region functions
Function Get-TenantDetail() {

    [cmdletbinding()]

    param
    (

    )

    $graphApiVersion = 'Beta'
    $Resource = 'organization'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Uri $uri -Method GET).value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
function Get-EntApplication {
    param (

        [Parameter(Mandatory = $true)]
        [string]$appName
    )

    try {
        # Query the application by display name
        (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$appName'").value
    }
    catch {
        Write-Error "Failed to retrieve or create application '$appName'. Error: $_"
        return $null
    }
}
function New-EntApplication {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appName
    )

    try {
        # Create the application
        Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/applicationTemplates/8adf8e6e-67b2-4cf2-a259-e3dc5476c621/instantiate' `
            -Body (@{ displayName = "$appName" } | ConvertTo-Json -Depth 2) `
            -ContentType 'application/json'
    }
    catch {
        Write-Error "Failed to retrieve or create application '$appName'. Error: $_"
        return $null
    }
}
function Set-EntApplication {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appObjID,

        [Parameter(Mandatory = $true)]
        [string]$internalServerName,

        [Parameter(Mandatory = $true)]
        [string]$externalServerName
    )

    $oPPBody = @{
        onPremisesPublishing = @{
            externalAuthenticationType = 'aadPreAuthentication'
            internalUrl                = "https://$internalServerName.com"
            externalUrl                = "https://$externalServerName-$tenantName.msappproxy.net"
        }
    }

    try {
        $JSON = $oPPBody | ConvertTo-Json -Depth 10 -Compress
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/applications/$appObjID" -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error "Failed to set on-premises publishing URLs. Error: $_"
    }
}
function New-AppConnectorGroup {
    param (

        [Parameter(Mandatory = $true)]
        [string]$name
    )

    try {
        $JSON = (@{ name = "$connectorGroupName" } | ConvertTo-Json -Depth 2)
        Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/beta/onPremisesPublishingProfiles/applicationProxy/connectorGroups' -Body $JSON -ContentType 'application/json'

    }
    catch {
        Write-Error "Failed to create Connector Group. Error: $_"

    }
}

# Function to assign App to Connector Group
function Update-AppConnectorGroup {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appObjID,

        [Parameter(Mandatory = $true)]
        [string]$ConnectorGroupId
    )

    $ref = '$ref' #pass $ref as a string into the invoke command
    try {
        $JSON = (@{ '@odata.id' = "https://graph.microsoft.com/beta/onPremisesPublishingProfiles/applicationProxy/connectorGroups/$ConnectorGroupId" } | ConvertTo-Json -Depth 2)
        Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/beta/applications/$appObjID/connectorGroup/$ref" -Body $JSON -ContentType 'application/json'
        Write-Host 'Application assigned to Connector Group successfully.'
    }
    catch {
        Write-Error "Failed to assign application to Connector Group. Error: $_"
    }
}

#endregion functions

<# Testing
$appName = 'IntuneSCEPv1'
$internalServerName = "$appName.com" #set to use appName for testing only
$externalServerName = "$appName" #set to use appName for testing only
$connectorGroupName = "$appName Connector Group"
#>

#region variables
$modules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Beta.Applications', 'Microsoft.Graph.Beta.Identity.DirectoryManagement')
$requiredScopes = @('Application.ReadWrite.All', 'Directory.ReadWrite.All')
[String[]]$scopes = $requiredScopes -join ', '
#endregion variables

#region module check
foreach ($module in $modules) {
    Write-Host "Checking for $module PowerShell module..." -ForegroundColor Cyan
    Write-Host ''
    If (!(Get-Module -Name $module -ListAvailable)) {
        Install-Module -Name $module -Scope CurrentUser -AllowClobber
    }
    Write-Host "PowerShell Module $module found." -ForegroundColor Green
    Write-Host ''
    if (!([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object FullName -Like "*$module*")) {
        Import-Module -Name $module -Force
    }
}
#endregion module check

#region connect to Graph
Connect-MgGraph -Scopes $scopes -NoWelcome
$context = Get-MgContext

#region scopes
$currentScopes = $context.Scopes
# Validate required permissions
$missingScopes = $requiredScopes | Where-Object { $_ -notin $currentScopes }
if ($missingScopes.Count -gt 0) {
    Write-Host 'WARNING: The following scope permissions are missing:' -ForegroundColor Red
    $missingScopes | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host ''
    Write-Host 'Please ensure these permissions are granted to the app registration for full functionality.' -ForegroundColor Yellow
    exit
}
Write-Host ''
Write-Host 'All required scope permissions are present.' -ForegroundColor Green
#endregion scopes

$tenantFullName = ((Get-TenantDetail).verifiedDomains | Where-Object { $_.isinitial -eq $true }).name
$tenantName = $tenantFullName -replace '\.onmicrosoft\.com', ''
#endregion connect to Graph

#region script
$appId = (Get-EntApplication -appName $appName).id
if ($null -eq $appId) {
    Write-Host "Enterprise Application $appName not found. Creating new application..." -ForegroundColor Cyan
    $entApp = New-EntApplication -appName $appName

    $appObjID = $($entApp.application.id)
    Set-EntApplication -appObjID $appObjID -internalServerName $internalServerName -externalServerName $externalServerName

    $appConnectorGroup = New-AppConnectorGroup -name $connectorGroupName
    Update-AppConnectorGroup -appObjID $appObjID -ConnectorGroupId $($appConnectorGroup.Id)

}
else {
    Write-Host "Enterprise Application $appName found. Please select a new name." -ForegroundColor Yellow
    break
}
#endregion script