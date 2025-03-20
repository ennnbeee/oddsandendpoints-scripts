param([switch]$includeDisabledRules, [switch]$includeLocalRules)

## check for elevation
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal $identity

if (!$principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host -ForegroundColor Red 'Error:  Must run elevated: run as administrator'
    Write-Host 'No commands completed'
    return
}

## check for running from correct folder location
Import-Module '.\FirewallRulesMigration.psm1'
. '.\IntuneFirewallRulesMigration\Private\Strings.ps1'

# Increase the Function Count
$MaximumFunctionCount = 32768


#Disconnect from Graph
if (Get-MgContext) {
    Write-Host 'Disconnecting from existing Graph session.' -ForegroundColor Cyan
    Disconnect-MgGraph
}

#region scopes
$requiredScopes = @('DeviceManagementManagedDevices.ReadWrite.All', 'DeviceManagementConfiguration.ReadWrite.All')
[String[]]$scopes = $requiredScopes -join ', '
#endregion scopes

#region Authentication
Write-Host 'Connecting to Microsoft Graph...' -ForegroundColor Cyan
Connect-MgGraph -Scopes $scopes
$context = Get-MgContext
$currentScopes = $context.Scopes
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

#endregion authentication

$profileName = ''
try {

    $json = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/deviceManagement/intents?$filter=templateId%20eq%20%274b219836-f2b1-46c6-954d-4cd2f4128676%27%20or%20templateId%20eq%20%274356d05c-a4ab-4a07-9ece-739f7c792910%27%20or%20templateId%20eq%20%275340aa10-47a8-4e67-893f-690984e4d5da%27'
    $profiles = $json.value
    $profileNameExist = $true
    $profileName = Read-Host -Prompt $Strings.EnterProfile
    while (-not($profileName)) {
        $profileName = Read-Host -Prompt $Strings.ProfileCannotBeBlank
    }
    while ($profileNameExist) {
        if (![string]::IsNullOrEmpty($profiles)) {
            foreach ($display in $profiles) {
                $name = $display.displayName.Split('-')
                $profileNameExist = $false
                if ($name[0] -eq $profileName) {
                    $profileNameExist = $true
                    $profileName = Read-Host -Prompt $Strings.ProfileExists
                    while (-not($profileName)) {
                        $profileName = Read-Host -Prompt $Strings.ProfileCannotBeBlank
                    }
                    break
                }
            }
        }
        else {
            $profileNameExist = $false
        }
    }
    $EnabledOnly = $true
    if ($includeDisabledRules) {
        $EnabledOnly = $false
    }

    if ($includeLocalRules) {
        Export-NetFirewallRule -ProfileName $profileName -CheckProfileName $false -EnabledOnly:$EnabledOnly -PolicyStoreSource 'All'
    }
    else {
        Export-NetFirewallRule -ProfileName $profileName -CheckProfileName $false -EnabledOnly:$EnabledOnly
    }

}
catch {
    $errorMessage = $_.ToString()
    Write-Host -ForegroundColor Red $errorMessage
    Write-Host 'No commands completed'
}


