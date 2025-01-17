[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,DeviceManagementApps.ReadWrite.All'

)

#region Functions
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
Function Get-AppCategory() {
    [cmdletbinding()]
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileAppCategories'
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-AppCategory() {
    [cmdletbinding()]
    param
    (
        $Name
    )
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileAppCategories'
    try {
        if ($Name -eq '' -or $null -eq $Name) {
            Write-Host 'No name specified, please specify valid Name for the App Category...' -f Red
            break
        }
        else {
            $Output = New-Object -TypeName psobject
            $Output | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.mobileAppCategory'
            $Output | Add-Member -MemberType NoteProperty 'displayName' -Value $Name
            $JSON = $Output | ConvertTo-Json -Depth 3
            Test-JSON -JSON $JSON
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-MobileApps() {
    [cmdletbinding()]
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileApps'
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-MobileAppsCategory() {
    [cmdletbinding()]
    param
    (
        $Id
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Id specified, please specify valid Id for the Mobile App...' -f Red
            break
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-MobileAppCategory() {
    [cmdletbinding()]
    param
    (
        $Id,
        $CategoryId
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories/`$ref"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Mobile App ID specified, please specify valid Id for the Mobile App ID...' -f Red
            break
        }
        elseif ($CategoryId -eq '' -or $null -eq $CategoryId) {
            Write-Host 'No App Category ID specified, please specify valid ID for the App Category...' -f Red
            break
        }
        else {
            $value = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/mobileAppCategories/$CategoryId"
            $Output = New-Object -TypeName psobject
            $Output | Add-Member -MemberType NoteProperty -Name '@odata.id' -Value $value
            $JSON = $Output | ConvertTo-Json -Depth 3
            Test-JSON -JSON $JSON
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Remove-MobileAppCategory() {
    [cmdletbinding()]
    param
    (
        $Id,
        $CategoryId
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories/$CategoryId/`$ref"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Mobile App ID specified, please specify valid Id for the Mobile App ID...' -f Red
            break
        }
        elseif ($CategoryId -eq '' -or $null -eq $CategoryId) {
            Write-Host 'No App Category ID specified, please specify valid ID for the App Category...' -f Red
            break
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-MgGraphRequest -Uri $uri -Method Delete
        }
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
$sleep = '5'
Write-Host '********************************************************************************'
Write-Host '****    Welcome to the Endpoint Manager App Category and Assignment Tool    ****' -ForegroundColor Green
Write-Host '****    This Script will add new app categories and assign them             ****' -ForegroundColor Cyan
Write-Host '********************************************************************************'
Write-Host
Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
Write-Host
Write-Host ' (1) Upload a CSV of new App Categories...' -ForegroundColor Green
Write-Host
Write-Host ' (2) Upload a CSV of new App Categories and assign App Categories to Apps...' -ForegroundColor Green
Write-Host
Write-Host ' (3) Assign App Categories to Apps...' -ForegroundColor Green
Write-Host
Write-Host ' (4) Remove Assigned App Categories from Apps...' -ForegroundColor Green
Write-Host
Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
Write-Host
$Choice_Number = ''
$Choice_Number = Read-Host -Prompt 'Based on which option you want to run, please type 1, 2 or E to exit the script, then hit enter '
while ( !($Choice_Number -eq '1' -or $Choice_Number -eq '2' -or $Choice_Number -eq '3' -or $Choice_Number -eq '4' -or $Choice_Number -eq 'E')) {
    $Choice_Number = Read-Host -Prompt 'Invalid Option, Based on which option you want to run, please type 1, 2, 3, 4 or E to exit the test, then click enter '
}
if ($Choice_Number -eq 'E') {
    Break
}
if ($Choice_Number -eq '1') {
    $Setting = 'Upload'
}
if ($Choice_Number -eq '2') {
    $Setting = 'Upload/Assign'
}
if ($Choice_Number -eq '3') {
    $Setting = 'Assign'
}
if ($Choice_Number -eq '4') {
    $Setting = 'Remove'
}
if ($Setting -like '*Upload*') {
    #region Add App Categories
    $CSVPath = Read-Host 'Please provide the path to the CSV file containing a list of App Categories e.g. C:\temp\appcategories.csv'
    if (!(Test-Path "$CSVPath")) {
        Write-Host "Import Path for CSV file doesn't exist" -ForegroundColor Red
        Write-Host "Script can't continue" -ForegroundColor Red
        Write-Host
        break
    }
    else {
        $AppCategories = Import-Csv -Path $CSVPath
    }
    $CurrentAppCategories = (Get-AppCategory).displayName
    foreach ($AppCategory in $AppCategories) {
        if ($AppCategory.Name -in $CurrentAppCategories) {
            Write-Host 'App Category '$AppCategory.Name' already exists...' -ForegroundColor Yellow
            Write-Host
        }
        else {
            Write-Host 'App Category will be created...' -ForegroundColor Yellow
            Write-Host
            try {
                Add-AppCategory -Name $AppCategory.Name | Out-Null
                Write-Host 'App Category '$AppCategory.Name' created...' -ForegroundColor Green
                Write-Host
            }
            catch {
                Write-Host 'App Category '$AppCategory.Name' not created...' -ForegroundColor Red
                Write-Host
            }
        }
    }
    #endregion
}
if ($Setting -like '*Assign*') {
    #region Assign App Categories
    Write-Host 'When prompted, wait for all Mobile Apps to load, then select the App or Apps you want to assign a Category. Use The ENTER Key or Mouse \ OK Button.' -ForegroundColor Yellow
    Write-Host
    Start-Sleep -Seconds $sleep
    $MobileApps = @(Get-MobileApps | Where-Object { (!($_.'@odata.type').Contains('managed')) -and (!($_.'@odata.type').Contains('android')) } | Select-Object '@odata.type', displayName, publisher, id | Out-GridView -PassThru -Title 'Select Mobile Apps...')
    Write-Host 'Wait for all App Categories to load, then select the Category or Categories you want to assign to an Application. Use The ENTER Key or Mouse \ OK Button.' -ForegroundColor Yellow
    Write-Host
    Start-Sleep -Seconds $sleep
    $AddAppCategories = @(Get-AppCategory | Select-Object displayName, id | Out-GridView -PassThru -Title 'Select Apps Categories...')
    Write-Host 'Starting assignment of Categories to Mobile Apps' -ForegroundColor Yellow
    Write-Host
    Write-Warning 'Please confirm you are happy to continue assigning categories to applications' -WarningAction Inquire
    foreach ($MobileApp in $MobileApps) {
        $AssignedAppCategories = Get-MobileAppsCategory -Id $MobileApp.id
        foreach ($AddAppCategory in $AddAppCategories) {
            if ($AddAppCategory.displayName -in $AssignedAppCategories.displayName) {
                Write-Host ''$AddAppCategory.displayName' category already assigned to '$MobileApp.displayName'' -ForegroundColor Yellow
                Write-Host
            }
            else {
                Write-Host 'Adding '$AddAppCategory.displayName' category to '$MobileApp.displayName'...' -ForegroundColor Yellow
                try {
                    Add-MobileAppCategory -Id $MobileApp.id -CategoryId $AddAppCategory.id
                    Write-Host 'Added '$AddAppCategory.displayName' category to '$MobileApp.displayName'...' -ForegroundColor Green
                    Write-Host
                }
                catch {
                    Write-Host 'Unable to add '$AddAppCategory.displayName' category to '$MobileApp.displayName'...' -ForegroundColor Red
                    Write-Host
                }
            }
        }
    }
    #endregion
}
if ($setting -eq 'Remove') {
    Write-Host 'When prompted, wait for all Mobile Apps to load, then select the App or Apps you want to remove categories from. Use The ENTER Key or Mouse \ OK Button.' -ForegroundColor Yellow
    Write-Host
    Start-Sleep -Seconds $sleep
    $MobileApps = @(Get-MobileApps | Where-Object { (!($_.'@odata.type').Contains('managed')) -and (!($_.'@odata.type').Contains('android')) } | Select-Object '@odata.type', displayName, publisher, id | Out-GridView -PassThru -Title 'Select Mobile Apps...')
    foreach ($MobileApp in $MobileApps) {
        $AssignedAppCategories = Get-MobileAppsCategory -Id $MobileApp.id
        If (!$AssignedAppCategories) {
            Write-Host 'App '$MobileApp.displayName' has no assigned App Categories...' -ForegroundColor Yellow
            Write-Host
        }
        Else {
            Write-Host 'The following App Categories for App '$MobileApp.displayName' will be removed...' -ForegroundColor Yellow
            $AssignedAppCategories.displayName
            Write-Host
            Start-Sleep -Seconds $sleep
            foreach ($AssignedAppCategory in $AssignedAppCategories) {
                Try {
                    Remove-MobileAppCategory -Id $MobileApp.id -CategoryId $AssignedAppCategory.id
                    Write-Host 'App Category '$AssignedAppCategory.displayName' removed from App '$MobileApp.displayName'' -ForegroundColor Green
                    Write-Host
                }
                Catch {
                    Write-Host 'Unable to remove App Category '$AssignedAppCategory.displayName' from App '$MobileApp.displayName'' -ForegroundColor Red
                    Write-Host
                }
            }
        }
    }
}