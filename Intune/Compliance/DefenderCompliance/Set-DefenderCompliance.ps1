[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

)

Function Test-JSON() {

    <#
    .SYNOPSIS
    This function is used to test if the JSON passed to a REST Post request is valid
    .DESCRIPTION
    The function tests if the JSON passed to the REST Post is valid
    .EXAMPLE
    Test-JSON -JSON $JSON
    Test if the JSON is valid before calling the Graph REST interface
    .NOTES
    NAME: Test-JSON
    #>

    param (

        $JSON

    )

    try {

        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
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
Function Get-DeviceCompliancePolicy() {

    <#
    .SYNOPSIS
    This function is used to get device compliance policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device compliance policies
    .EXAMPLE
    Get-DeviceCompliancePolicy
    Returns any device compliance policies configured in Intune
    .EXAMPLE
    Get-DeviceCompliancePolicy -Android
    Returns any device compliance policies for Android configured in Intune
    .EXAMPLE
    Get-DeviceCompliancePolicy -iOS
    Returns any device compliance policies for iOS configured in Intune
    .NOTES
    NAME: Get-DeviceCompliancePolicy
    #>

    [cmdletbinding()]


    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/deviceCompliancePolicies'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value

    }

    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}

Function Update-DeviceCompliancePolicy() {

    <#
    .SYNOPSIS
    This function is used to update device compliance policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and updates device compliance policies
    .EXAMPLE
    Update-DeviceCompliancePolicy -id -JSON
    Updates a device compliance policies configured in Intune
    .NOTES
    NAME: Update-DeviceCompliancePolicy
    #>

    [cmdletbinding()]
    param
    (
        $Id,
        $JSON
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/deviceCompliancePolicies/$id"

    try {

        if (!$Id) {

            Write-Host 'No Compliance Policy Id specified, specify a valid Compliance Policy Id' -f Red
            break

        }

        if ($JSON -eq '' -or $null -eq $JSON) {

            Write-Host 'No JSON specified, please specify valid JSON for the Compliance Policy...' -f Red

        }

        else {

            Test-Json -Json $JSON

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $JSON -ContentType 'application/json'
            Write-Host
            Write-Host 'Successfully Updated Compliance Policy' -ForegroundColor Green

        }

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}

Function Get-LatestDefenderPlatformUpdate() {

    try {

        $uri = 'https://support.microsoft.com/en-us/feed/atom/5d4715e7-a9c9-378e-3f83-fd410db4ef0a'
        [xml]$Updates = (Invoke-WebRequest -Uri $uri -UseBasicParsing -ContentType 'application/xml').Content -replace '[^\x09\x0A\x0D\x20-\xD7FF\xE000-\xFFFD\x10000-x10FFFF]', ''
        $DefenderUpdateUri = @()
        foreach ($Update in $Updates.feed.entry) {
            if ($Update.title.'#text' -like '*platform*') {
                $DefenderUpdateUri += $Update.link.href
            }
        }

        $DefenderPlatformUpdate = Invoke-WebRequest -Uri $($DefenderUpdateUri[0])
        $DefenderPlatformVersion = (($DefenderPlatformUpdate.Content).tostring() -split "[`r`n]" | Select-String 'New version:') -replace '[^0-9.]'

        Write-Host
        Write-Host "Latest Defender Platform version - $DefenderPlatformVersion" -ForegroundColor Magenta
        $DefenderPlatformVersion

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

$Date = Get-Date
$Description = "Updated Defender Antivirus Compliance Policy on $Date"
$DefenderPlatformVersion = Get-LatestDefenderPlatformUpdate

$Update = New-Object -TypeName psobject
$Update | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.windows10CompliancePolicy'
$Update | Add-Member -MemberType NoteProperty -Name 'description' -Value $Description

$DefenderCompliancePolicies = Get-DeviceCompliancePolicy | Where-Object { ($_.'@odata.type').contains('windows10CompliancePolicy') -and ($_.defenderEnabled) -ne '' }
foreach ($DefenderCompliancePolicy in $DefenderCompliancePolicies) {
    if ($DefenderCompliancePolicy.defenderVersion -lt $DefenderPlatformVersion) {
        Write-Host
        Write-Host "Updating Defender Antivirus Compliance Policy - $($DefenderCompliancePolicy.displayname)" -ForegroundColor Green

        $Update | Add-Member -MemberType NoteProperty -Name 'defenderVersion' -Value $DefenderPlatformVersion

        # Creating JSON object to pass to Graph
        $JSON = $Update | ConvertTo-Json -Depth 3

        # Updating the compliance policy
        Update-DeviceCompliancePolicy -Id $DefenderCompliancePolicy.id -JSON $JSON
    }
    else {
        Write-Host "Defender Antivirus Compliance Policy - $($DefenderCompliancePolicy.displayname) is already up to date" -ForegroundColor Yellow
    }

}