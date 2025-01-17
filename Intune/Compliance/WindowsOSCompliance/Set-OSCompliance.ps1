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
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-LatestWindowsUpdatesBuild() {

    <#
    .SYNOPSIS
    This function is used to get the latest Windows Updates from the Microsoft RSS Feeds
    .DESCRIPTION
    The function pulls the RSS feed from the Microsoft RSS Feeds
    .EXAMPLE
    Get-LatestWindowsUpdatesBuild -OS 10 -Build 19043
    Gets the updates for Windows
    .NOTES
    NAME: Get-WindowsUpdatesInfo
    #>

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Windows 10', 'Windows 11')]
        $OS,
        [Parameter(Mandatory = $true)]
        $Version
    )
    try {

        if ($OS -eq 'Windows 10') {
            $uri = 'https://support.microsoft.com/en-us/feed/atom/6ae59d69-36fc-8e4d-23dd-631d98bf74a9'
            #$uri = 'https://kbupdate.info/rss.php?windows-10'
        }
        elseif ($OS -eq 'Windows 11') {
            $uri = 'https://support.microsoft.com/en-us/feed/atom/4ec863cc-2ecd-e187-6cb3-b50c6545db92'
            #$uri = 'https://kbupdate.info/rss.php?windows-11'
        }

        [xml]$Updates = (Invoke-WebRequest -Uri $uri -UseBasicParsing -ContentType 'application/xml').Content -replace '[^\x09\x0A\x0D\x20-\xD7FF\xE000-\xFFFD\x10000-x10FFFF]', ''

        $BuildVersions = @()

        foreach ($Update in $Updates.feed.entry) {
            if (($update.title.'#text' -like "*$Version*") -and ($update.title.'#text' -notlike '*Preview*') -and ($update.title.'#text' -notlike '*Out-of-band*')) {
                $BuildVersions += $update.title.'#text'
            }
        }
        Return $BuildVersions[0].Substring($BuildVersions[0].LastIndexOf('.')) -replace '[^0-9]'

    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-AppleUpdates() {

    <#
    .SYNOPSIS
    This function is used to get the latest Apple Updates from the Apple Developer RSS Feeds
    .DESCRIPTION
    The function pulls the RSS feed from the Apple Developer RSS Feeds
    .EXAMPLE
    Get-AppleUpdates -OS iOS -Version 15
    #>

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('iOS', 'macOS')]
        $OS,
        [Parameter(Mandatory = $true)]
        $Version
    )

    try {
        $uri = 'https://developer.apple.com/news/releases/rss/releases.rss'
        [xml]$Updates = (Invoke-WebRequest -Uri $uri -UseBasicParsing -ContentType 'application/xml').Content -replace '[^\x09\x0A\x0D\x20-\xD7FF\xE000-\xFFFD\x10000-x10FFFF]', ''

        $BuildVersion = @()
        foreach ($Update in $Updates.rss.channel.Item) {
            if (($Update.title -like "*$OS*") -and ($Update.title -like "*$Version*")) {
                $BuildVersion += $Update.title
            }
        }
        return $BuildVersion[0]
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


$Date = Get-Date -Format 'dd-MM-yyyy hh:mm:ss'
$Description = "Updated Operating System Device Compliance Policy on $Date"

$OSCompliancePolicies = Get-DeviceCompliancePolicy | Where-Object { ((($_.'@odata.type').contains('iosCompliancePolicy') -or ($_.'@odata.type').contains('macOSCompliancePolicy')) -and ($_.osMinimumVersion) -ne $null) -or (($_.'@odata.type').contains('windows10CompliancePolicy') -and ($_.validOperatingSystemBuildRanges) -ne '') }

$OSCompliancePolicies = Get-DeviceCompliancePolicy | Where-Object { (($_.'@odata.type').contains('windows10CompliancePolicy') -and ($_.validOperatingSystemBuildRanges) -ne '') }

foreach ($OSCompliancePolicy in $OSCompliancePolicies) {
    $Update = New-Object -TypeName psobject
    $Update | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value $OSCompliancePolicy.'@odata.type'
    $Update | Add-Member -MemberType NoteProperty -Name 'description' -Value $Description

    if (($OSCompliancePolicy.'@odata.type' -like '*ios*') -or ($OSCompliancePolicy.'@odata.type' -like '*macOS*')) {
        if ($OSCompliancePolicy.'@odata.type' -like '*ios*') {
            $OS = 'iOS'
        }
        elseif ($OSCompliancePolicy.'@odata.type' -like '*macOS*') {
            $OS = 'macOS'
        }

        $Version = $OSCompliancePolicy.osMinimumVersion.SubString(0, 2)
        $Build = (Get-AppleUpdates -OS $OS -Version $Version | Select-String '(?<=\()[^]]+(?=\))' -AllMatches).Matches.Value

        If ($OSCompliancePolicy.osMinimumBuildVersion -ne $Build) {
            $Update | Add-Member -MemberType NoteProperty -Name 'osMinimumBuildVersion' -Value $Build
            $JSON = $Update | ConvertTo-Json -Depth 3
            Update-DeviceCompliancePolicy -Id $OSCompliancePolicy.id -JSON $JSON
            Write-Host "Updated $OS Compliance Policy $($OSCompliancePolicy.displayName) with latest Build" -ForegroundColor Green
        }
        Else {
            Write-Host "$OS Compliance Policy $($OSCompliancePolicy.displayName) already on latest Build: $Build" -ForegroundColor Cyan
        }
    }
    elseif ($OSCompliancePolicy.'@odata.type' -like '*windows*') {
        $OSBuilds = $OSCompliancePolicy.validOperatingSystemBuildRanges
        $OSUpdates = @()

        foreach ($OSBuild in $OSBuilds) {
            if ($OSBuild.lowestVersion -like '*10.0.1*') {
                $OS = 'Windows 10'
            }
            elseif ($OSbuild.lowestVersion -like '*10.0.2*') {
                $OS = 'Windows 11'
            }

            $OSVersion = $OSBuild.lowestVersion.Split('.')[2]
            $BuildVersion = Get-LatestWindowsUpdatesBuild -OS $OS -Version $OSVersion
            $NewOSBuildVersion = '10.0.' + $OSVersion + '.' + $BuildVersion
            $OSUpdate = New-Object -TypeName psobject

            $OSUpdate | Add-Member -MemberType NoteProperty -Name 'description' -Value $OSBuild.description
            $OSUpdate | Add-Member -MemberType NoteProperty -Name 'highestVersion' -Value $OSBuild.highestVersion

            If ($OSBuild.lowestVersion -ne $NewOSBuildVersion) {
                $OSUpdate | Add-Member -MemberType NoteProperty -Name 'lowestVersion' -Value $NewOSBuildVersion
            }
            Else {
                $OSUpdate | Add-Member -MemberType NoteProperty -Name 'lowestVersion' -Value $OSBuild.lowestVersion
            }

            $OSUpdates += $OSUpdate
        }

        $Update | Add-Member -MemberType NoteProperty -Name 'validOperatingSystemBuildRanges' -Value @($OSUpdates)
        $JSON = $Update | ConvertTo-Json -Depth 3
        Update-DeviceCompliancePolicy -Id $OSCompliancePolicy.id -JSON $JSON
        Write-Host "Updated Windows Compliance Policy $($OSCompliancePolicy.displayName) with latest Builds" -ForegroundColor Green
    }
}

