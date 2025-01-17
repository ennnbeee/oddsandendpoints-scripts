<#
  .SYNOPSIS
  Converts existing Firewall Rules profiles to Settings Catalog versions.

  .DESCRIPTION
  The Invoke-MgConvertFirewallRules.ps1 script using Graph PowerShell tooling to capture all details of existing migrated
  firewall rules, and reprocesses them in the new Settings Catalog format.

  .PARAMETER tenantId
  Provide the Id of the tenant to connecto to.

  .PARAMETER policyName
  The name of the new Firewall Rules policy, or in the event of multiple rules, each create Firewall Rule profile.

  .PARAMETER oldFirewallPolicies
  A list, or array, of the old Firewall Rule policies that are to be converted.

  .PARAMETER Scopes
  The scopes used to connect to the Graph API using PowerShell.
  Default scopes configured are:
  'Device.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

  .INPUTS
  None. You can't pipe objects to Invoke-MgConvertFirewallRules.ps1

  .OUTPUTS
  None. Invoke-MgConvertFirewallRules.ps1 doesn't generate any output.

  .EXAMPLE
  PS> .\Invoke-MgConvertFirewallRules.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -policyName 'CO_FW_Rules' -oldFirewallPolicies 'Legacy_FW_Rule1','Legacy_FW_Rule2','Legacy_FW_Rule3'

#>

[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $true)]
    [String]$policyName,

    [Parameter(Mandatory = $true)]
    [String[]]$oldFirewallPolicies,

    [Parameter(Mandatory = $false)]
    [String[]]$Scopes = 'DeviceManagementConfiguration.ReadWrite.All'

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
Function New-DeviceSettingsCatalog() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON
    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/configurationPolicies'

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
Function Get-DeviceEndpointSecProfile() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        $name,

        [Parameter(Mandatory = $false)]
        $Id

    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/intents'

    try {
        if ($Id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$Id"
            Invoke-MgGraphRequest -Uri $uri -Method Get
        }
        elseif ($name) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value | Where-Object { ($_.displayName).contains("$name") }
        }
        Else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Method Get -Uri $uri).value
        }
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-DeviceEndpointSecCategorySetting() {

    <#
    .SYNOPSIS
    This function is used to get an Endpoint Security category setting from a specific policy using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets a policy category setting
    .EXAMPLE
    Get-EndpointSecurityCategorySetting -PolicyId $policyId -categoryId $categoryId
    Gets an Endpoint Security Categories from a specific template in Endpoint Manager
    .NOTES
    NAME: Get-EndpointSecurityCategory
    #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]

        $Id,
        [Parameter(Mandatory = $true)]

        $categoryId
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/intents/$Id/categories/$categoryId/settings?`$expand=Microsoft.Graph.DeviceManagementComplexSettingInstance/Value"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Method Get -Uri $uri).value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-DeviceEndpointSecTemplateCategory() {

    <#
    .SYNOPSIS
    This function is used to get all Endpoint Security categories from a specific template using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets all template categories
    .EXAMPLE
    Get-EndpointSecurityTemplateCategory -TemplateId $templateId
    Gets an Endpoint Security Categories from a specific template in Endpoint Manager
    .NOTES
    NAME: Get-EndpointSecurityTemplateCategory
    #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]

        $Id
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/templates/$Id/categories"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Method Get -Uri $uri).value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-DeviceEndpointSecTemplate() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        $name,

        [Parameter(Mandatory = $false)]
        $Id

    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/templates?`$filter=(isof(%27microsoft.graph.securityBaselineTemplate%27))"

    try {
        if ($Id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$Id"
            Invoke-MgGraphRequest -Uri $uri -Method Get
        }
        elseif ($name) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value | Where-Object { ($_.displayName).contains("$name") }
        }
        Else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Method Get -Uri $uri).value
        }
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
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
    }

    $graphDetails = Get-MgContext
    if ($null -eq $graphDetails) {
        Write-Host "Not connected to Graph, please review any errors and try to run the script again' cmdlet." -ForegroundColor Red
        break
    }
}
#endregion authentication


Write-Host '█▀▀ █ █▀█ █▀▀ █░█░█ ▄▀█ █░░ █░░   █▀█ █░█ █░░ █▀▀   █▀▀ █▀█ █▄░█ █░█ █▀▀ █▀█ ▀█▀ █▀▀ █▀█' -ForegroundColor Red
Write-Host '█▀░ █ █▀▄ ██▄ ▀▄▀▄▀ █▀█ █▄▄ █▄▄   █▀▄ █▄█ █▄▄ ██▄   █▄▄ █▄█ █░▀█ ▀▄▀ ██▄ █▀▄ ░█░ ██▄ █▀▄' -ForegroundColor Red
Write-Host
Write-Host ('Connected to Tenant {0} as account {1}' -f $graphDetails.TenantId, $graphDetails.Account) -ForegroundColor Green
Write-Host 'Starting the Intune Firewall Converter Script...' -ForegroundColor Magenta
Write-Host
Write-Host 'The name of the Firewall Rules to be converted:' -ForegroundColor Green
$oldFirewallPolicies
Write-Host
Write-Host 'The name of the new Firewall Rules will start with:' -ForegroundColor Green
$policyName
Write-Host
Write-Warning 'Please review the above and confirm you are happy to continue.' -WarningAction Inquire
Write-Host
# Get the existing FW policy and settings

# Testing
#$policyName = 'New'
#$oldFirewallPolicies = @('MIG_CO_FW_DefenderFirewallRules')

# Variables for Template IDs and to capture Rules
$fwRules = @()
$fwTemplateID = '4356d05c-a4ab-4a07-9ece-739f7c792910'

foreach ($oldFirewallPolicy in $oldFirewallPolicies) {
    $endpointSecProfile = Get-DeviceEndpointSecProfile -Name $oldFirewallPolicy
    if (($null -eq $endpointSecProfile) -or ($endpointSecProfile.templateId -ne $fwTemplateID)) {
        Write-Host "Unable to find Legacy Firewall Rule Profile named $oldFirewallPolicy or $oldFirewallPolicy Profile is not a Firewall Rule profile, script will end." -ForegroundColor Red
        Break
    }
    else {
        $endpointSecTemplates = Get-DeviceEndpointSecTemplate
        $endpointSecTemplate = $endpointSecTemplates | Where-Object { $_.id -eq $endpointSecProfile.templateId }
        $endpointSecCategories = Get-DeviceEndpointSecTemplateCategory -Id $endpointSecTemplate.id
        Write-Host "Found Legacy Firewall Rule Profile $oldFirewallPolicy" -ForegroundColor Green
        foreach ($EndpointSecCategory in $endpointSecCategories) {
            $endpointSecSettings = Get-DeviceEndpointSecCategorySetting -Id $endpointSecProfile.id -categoryId $endpointSecCategories.id
            # Existing FW rules
            $fwRules += $endpointSecSettings.valueJson | ConvertFrom-Json
        }
    }
}

Write-Host "Captured $($fwRules.count) rules from the provided legacy Endpoint Security Firewall Rules profiles." -ForegroundColor Green

# Sorting rules into groups of 100 for Setting Catalog requirements
$counter = [pscustomobject] @{ Value = 0 }
$groupSize = 100
$fwRuleGroups = $fwRules | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) }

# Looping through each group of rules
foreach ($fwRuleGroup in $fwRuleGroups) {

    # Sets the Name of the policies
    $newPolicyName = $policyName + '-' + $fwRuleGroup.Name
    $policyDescription = 'Converted Firewall Rules Policy'

    # New Settings Catalog policy start and end

    $JSONPolicyStart = @"
{
    "description": "$policyDescription",
    "name": "$newPolicyName",
    "platforms": "windows10",
    "technologies@odata.type": "#microsoft.graph.deviceManagementConfigurationTechnologies",
    "technologies": "mdm,microsoftSense",
    "templateReference": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationPolicyTemplateReference",
        "templateId": "19c8aa67-f286-4861-9aa0-f23541d31680_1",
        "templateFamily@odata.type": "#microsoft.graph.deviceManagementConfigurationTemplateFamily",
        "templateFamily": "endpointSecurityFirewall",
        "templateDisplayName": "Microsoft Defender Firewall Rules",
        "templateDisplayVersion": "Version 1"
    },
    "settings": [
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSetting",
            "settingInstance": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "76c7a8be-67d2-44bf-81a5-38c94926b1a1"
                },
                "groupSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationGroupSettingValue)",
                "groupSettingCollectionValue": [

"@

    $JSONPolicyEnd = @'
                ]
            }
        }
    ]
}
'@

    # Processing the rules
    $JSONAllRules = @()
    $rules = $fwRuleGroup.Group
    $RuleNameCount = 0
    foreach ($rule in $rules) {

        # Capturing existing rules with duplicate names, as Settings Catalog will not allow duplicates
        $duplicateNames = $rules.displayName | Group-Object | Where-Object { $_.count -gt 1 }

        # Blank Out variables as not all rules have each variable
        Clear-Variable JSONRule*
        Clear-Variable -Name ('Name', 'Description', 'Direction', 'Action', 'FWProfiles', 'PackageFamilyName', 'FilePath', 'Service', 'Protocol', 'LocalPorts', 'RemotePorts', 'Interfaces', 'UseAnyLocalAddresses', 'LocalAddresses', 'UseAnyRemoteAddresses', 'RemoteAddresses') -ErrorAction Ignore

        # Capturing the Rule Data
        $name = $rule.displayName
        if ($duplicateNames.name -contains $name) {
            $name = $name + '-' + $RuleNameCount++
        }
        $description = $rule.description
        $direction = $rule.trafficDirection
        $action = $rule.action
        $fwProfiles = $rule.profileTypes
        $packageFamilyName = $rule.packageFamilyName
        $filePath = ($rule.filePath).Replace('\', '\\')
        $service = $rule.serviceName
        $protocol = $rule.protocol
        $localPorts = $rule.localPortRanges
        $remotePorts = $rule.remotePortRanges
        $interfaces = $rule.interfaceTypes
        $authUsers = $rule.localUserAuthorizations
        $useAnyLocalAddresses = $rule.useAnyLocalAddressRange
        $localAddresses = $rule.actualLocalAddressRanges
        $useAnyRemoteAddresses = $rule.useAnyRemoteAddressRange
        $remoteAddresses = $rule.actualRemoteAddressRanges

        # Setting the Start of each rule
        $JSONRuleStart = @'
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationGroupSettingValue",
            "settingValueTemplateReference": null,
            "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
            "children": [
'@

        # JSON data is different for first rule in the policy
        if ($rule -eq $rules[0]) {
            # Rule Name
            $JSONRuleName = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_name",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "116a696a-3270-493e-9938-c336cf05ea98"
            },
            "simpleSettingValue": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                "value": "$name",
                "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "12994a33-6185-4c3d-a0e8-69316f6293ea",
                    "useTemplateDefault": false
                }
            }
        },

"@

            # Rule State (Enabled)
            $JSONRuleState = @'
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_enabled",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "4e150e1a-6a10-49b2-a20c-911bf44ea767"
            },
            "choiceSettingValue": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_enabled_1",
                "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "7562f243-f281-4f6f-b7e6-ecdb76dc1f1b",
                    "useTemplateDefault": false
                },
                "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                "children": []
            }
        },

'@

            # Rule Direction
            $JSONRuleDirection = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_direction",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "2114ad3d-157c-47d3-b646-60fcf50949c7"
            },
            "choiceSettingValue": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_direction_$direction",
                "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "8b45e13b-952d-4164-bbac-37f4e97b7985",
                    "useTemplateDefault": false
                },
                "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                "children": []
            }
        },

"@

            # Edge Traversal
            <#$JSONRuleEdgeTraversal = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_edgetraversal",
                "settingInstanceTemplateReference": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                  "settingInstanceTemplateId": "fe674767-404d-4994-ac86-016f209851ee"
                },
                "choiceSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                  "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_edgetraversal_1",
                  "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "682b3827-caec-4378-99b3-0400c2c0537b",
                    "useTemplateDefault": false
                  },
                  "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                  "children": []
                }
            },
'@#>
            # Protocol
            if ($null -ne $protocol) {
                $JSONRuleProtocol = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_protocol",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "b8f45398-674f-40c3-ab18-e002aa8e589b"
                    },
                "simpleSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationIntegerSettingValue",
                    "value": "$protocol",
                    "settingValueTemplateReference": {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                        "settingValueTemplateId": "27d0d86c-d87d-473b-a41c-eef503d8baec",
                        "useTemplateDefault": false
                    }
                }
            },

"@
            }

            # Local Address Ranges
            if ($useAnyLocalAddresses -eq $false) {
                $JSONRuleLocalAddressRangeStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localaddressranges",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "8b5de251-c683-4440-91d6-3b679b0aa5aa"
                },
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONLocalAddresses = @()
                foreach ($LocalAddress in $localAddresses) {
                    # Last address in the set
                    if (($LocalAddress -eq $localAddresses[-1]) -or ($localAddresses.count -eq '1')) {
                        $JSONRuleLocalAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalAddress"
                    }

"@
                    }
                    else {
                        $JSONRuleLocalAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalAddress"
                    },

"@
                    }
                    $JSONLocalAddresses += $JSONRuleLocalAddress
                }
                $JSONRuleLocalAddressRangeEnd = @'

                ]
            },

'@
                $JSONRuleLocalAddressRange = $JSONRuleLocalAddressRangeStart + $JSONLocalAddresses + $JSONRuleLocalAddressRangeEnd
            }

            # Interface Type
            if ($interfaces -ne 'notConfigured') {
                $JSONRuleInterface = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_interfacetypes",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "406b5410-e52e-4df3-933f-1ee6e550a5c8"
                },
                "choiceSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationChoiceSettingValue)",
                "choiceSettingCollectionValue": [
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_interfacetypes_all",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    }
                ]
            },

'@
            }

            # Package Family Name
            If (!([string]::IsNullOrEmpty($packageFamilyName))) {
                $JSONRulePackageFamily = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_packagefamilyname",
                "settingInstanceTemplateReference": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                  "settingInstanceTemplateId": "1a91448b-b04e-4cb0-a80c-10ec64addfda"
                },
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                  "value": "$packageFamilyName",
                  "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "a9b123c6-1c6f-4de3-8840-34f91dfb9422",
                    "useTemplateDefault": false
                  }
                }
            },

"@
            }

            # App File Path
            if (!([string]::IsNullOrEmpty($filePath))) {
                $JSONRuleFilePath = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_filepath",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "dd825fa0-961b-4fcc-a6b3-4d2dc0419d4e"
                },
                "simpleSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                    "value": "$filePath",
                    "settingValueTemplateReference": {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                        "settingValueTemplateId": "8c94fefa-67e5-40b5-8d97-6fca4f0c1e98",
                        "useTemplateDefault": false
                    }
                }
            },

"@
            }

            # Authorized Users
            if (!([string]::IsNullOrEmpty($authUsers))) {
                $JSONRuleAuthUsersStart = @'
                {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                    "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localuserauthorizedlist",
                    "settingInstanceTemplateReference": {
                      "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                      "settingInstanceTemplateId": "b11c8e7d-babc-4899-a4b4-04683b898faa"
                    },
                    "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                    "simpleSettingCollectionValue": [

'@
                $JSONAuthUsers = @()
                foreach ($AuthUser in $authUsers) {
                    # Last address in the set
                    if (($AuthUser -eq $authUsers[-1]) -or ($authUsers.count -eq '1')) {
                        $JSONRuleAuthUser = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$AuthUser"
                    }

"@
                    }
                    else {
                        $JSONRuleAuthUser = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$AuthUser"
                    },

"@
                    }
                    $JSONAuthUsers += $JSONRuleAuthUser
                }
                $JSONRuleAuthUsersEnd = @'

                ]
            },
'@
                $JSONRuleAuthUsers = $JSONRuleAuthUsersStart + $JSONAuthUsers + $JSONRuleAuthUsersEnd
            }
            # Remote Ports
            if (!([string]::IsNullOrEmpty($remotePorts))) {
                $JSONRuleRemotePortsStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_remoteportranges",
                "settingInstanceTemplateReference": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                  "settingInstanceTemplateId": "de5d058e-ab1d-4772-81f5-32b6a35b4587"
                },
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONRemotePorts = @()
                foreach ($RemotePort in $remotePorts) {
                    # Last address in the set
                    if (($RemotePort -eq $remotePorts[-1]) -or ($remotePorts.count -eq '1')) {
                        $JSONRuleRemotePort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemotePort"
                    }

"@
                    }
                    else {
                        $JSONRuleRemotePort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemotePort"
                    },

"@
                    }
                    $JSONRemotePorts += $JSONRuleRemotePort
                }
                $JSONRuleRemotePortsEnd = @'

                ]
            },

'@
                $JSONRuleRemotePorts = $JSONRuleRemotePortsStart + $JSONRemotePorts + $JSONRuleRemotePortsEnd
            }

            # Firewall Profile
            if ($fwProfiles -ne 'notConfigured') {
                $JSONRuleFWProfileStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "7dc9b243-cdd2-4359-b5f5-0c48edb8fd34"
                },
                "choiceSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationChoiceSettingValue)",
                "choiceSettingCollectionValue": [

'@

                $JSONRuleFWProfileTypes = @()
                foreach ($FWProfile in $fwProfiles) {
                    Switch ($FWProfile) {
                        'domain' { $FWProfileNo = '1' }
                        'private' { $FWProfileNo = '2' }
                        'public' { $FWProfileNo = '4' }
                    }

                    if (($FWProfile -eq $fwProfiles[-1]) -or ($fwProfiles.count -eq '1')) {
                        $JSONRuleFWProfileType = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles_$FWProfileNo",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    }

"@
                    }
                    else {
                        $JSONRuleFWProfileType = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles_$FWProfileNo",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    },

"@
                    }

                    $JSONRuleFWProfileTypes += $JSONRuleFWProfileType
                }

                $JSONRuleFWProfileEnd = @'
                ]
            },

'@

                $JSONRuleFWProfile = $JSONRuleFWProfileStart + $JSONRuleFWProfileTypes + $JSONRuleFWProfileEnd
            }

            # Service Name
            if (!([string]::IsNullOrEmpty($service))) {
                $JSONRuleService = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_servicename",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "1bd709fe-1cd4-4cc4-9a6f-4cb7f104da66"
                },
                "simpleSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                    "value": "$service",
                    "settingValueTemplateReference": {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                        "settingValueTemplateId": "c77294ec-795e-43dc-9af6-775b3b2f911d",
                        "useTemplateDefault": false
                    }
                }
            },

"@
            }

            # Local Ports
            if ((!([string]::IsNullOrEmpty($localPorts)))) {
                $JSONRuleLocalPortsStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localportranges",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "b57dc83e-5bf3-439a-b923-4c3e49ac9e2d"
                },
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONLocalPorts = @()
                foreach ($LocalPort in $localPorts) {
                    # Last address in the set
                    if (($LocalPort -eq $localPorts[-1]) -or ($localPorts.count -eq '1')) {
                        $JSONRuleLocalPort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalPort"
                    }

"@
                    }
                    else {
                        $JSONRuleLocalPort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalPort"
                    },

"@
                    }
                    $JSONLocalPorts += $JSONRuleLocalPort
                }
                $JSONRuleLocalPortsEnd = @'

                ]
            },

'@
                $JSONRuleLocalPorts = $JSONRuleLocalPortsStart + $JSONLocalPorts + $JSONRuleLocalPortsEnd
            }

            # Remote Address Ranges
            if ($useAnyRemoteAddresses -eq $false) {
                $JSONRuleRemoteAddressRangeStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_remoteaddressranges",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "bf9855fc-f2c0-4241-94cf-94cf823f1c1c"
                },
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONRemoteAddresses = @()
                foreach ($RemoteAddress in $remoteAddresses) {
                    # Last address in the set
                    if (($RemoteAddress -eq $remoteAddresses[-1]) -or ($remoteAddresses.count -eq '1')) {
                        $JSONRuleRemoteAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemoteAddress"
                    }

"@
                    }
                    else {
                        $JSONRuleRemoteAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemoteAddress"
                    },

"@
                    }
                    $JSONRemoteAddresses += $JSONRuleRemoteAddress
                }
                $JSONRuleRemoteAddressRangeEnd = @'

                ]
            },

'@
                $JSONRuleRemoteAddressRange = $JSONRuleRemoteAddressRangeStart + $JSONRemoteAddresses + $JSONRuleRemoteAddressRangeEnd
            }

            # Rule Action
            Switch ($action) {
                'allowed' { $ActionType = '1' }
                'blocked' { $ActionType = '0' }
            }
            $JSONRuleAction = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_action_type",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "0565cfd1-21c2-4965-b87f-6bde2b8d2cbd"
            },
            "choiceSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                    "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_action_type_$ActionType",
                    "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "419773d8-bffe-4d6f-a91f-286871963f5c",
                    "useTemplateDefault": false
            },
            "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
            "children": []
            }
        },

"@

            # Rule Description
            $JSONRuleDescription = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_description",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "6c85987f-3adb-4f8d-93e1-4f23e238121b"
            },
            "simpleSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                    "value": "$description",
                    "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "18ab9c3a-b6be-4995-9438-289c34eee294",
                    "useTemplateDefault": false
                }
            }
        }

"@

            #Rule ending
            if ($rule -eq $rules[-1]) {
                $JSONRuleEnd = @'
                ]
            }

'@
            }
            else {
                $JSONRuleEnd = @'
                ]
            },

'@
            }

            # Build the first Rule and add it to array
            $JSONRule = $JSONRuleStart + $JSONRuleName + $JSONRuleState + $JSONRuleDirection + $JSONRuleProtocol + $JSONRuleLocalAddressRange + $JSONRuleInterface + $JSONRulePackageFamily + $JSONRuleFilePath + $JSONRuleAuthUsers + $JSONRuleRemotePorts + $JSONRuleFWProfile + $JSONRuleService + $JSONRuleLocalPorts + $JSONRuleRemoteAddressRange + $JSONRuleAction + $JSONRuleDescription + $JSONRuleEnd
            $JSONAllRules += $JSONRule
        }
        # JSON data is different for each subsequent rule in the policy
        else {
            # Rule Name
            $JSONRuleName = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_name",
            "settingInstanceTemplateReference": null,
            "simpleSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
              "settingValueTemplateReference": null,
              "value": "$name"
            }
        },

"@

            # Rule State (Enabled)
            $JSONRuleState = @'
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_enabled",
            "settingInstanceTemplateReference": null,
            "choiceSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
              "settingValueTemplateReference": null,
              "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_enabled_1",
              "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
              "children": []
            }
        },

'@

            # Rule Direction
            $JSONRuleDirection = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_direction",
            "settingInstanceTemplateReference": null,
            "choiceSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
              "settingValueTemplateReference": null,
              "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_direction_$direction",
              "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
              "children": []
            }
        },

"@

            # Edge Traversal
            <#$JSONRuleEdgeTraversal = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_edgetraversal",
                "settingInstanceTemplateReference": null,
                "choiceSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_edgetraversal_1",
                  "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                  "children": []
                }
            },
'@#>
            # Protocol
            if ($null -ne $protocol) {
                $JSONRuleProtocol = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_protocol",
                "settingInstanceTemplateReference": null,
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationIntegerSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "$protocol"
                }
            },

"@
            }

            # Local Address Ranges
            if ($useAnyLocalAddresses -eq $false) {
                $JSONRuleLocalAddressRangeStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localaddressranges",
                "settingInstanceTemplateReference": null,
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONLocalAddresses = @()
                foreach ($LocalAddress in $localAddresses) {
                    # Last address in the set
                    if (($LocalAddress -eq $localAddresses[-1]) -or ($localAddresses.count -eq '1')) {
                        $JSONRuleLocalAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalAddress"
                    }

"@
                    }
                    else {
                        $JSONRuleLocalAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalAddress"
                    },

"@
                    }
                    $JSONLocalAddresses += $JSONRuleLocalAddress
                }
                $JSONRuleLocalAddressRangeEnd = @'

                ]
            },
'@
                $JSONRuleLocalAddressRange = $JSONRuleLocalAddressRangeStart + $JSONLocalAddresses + $JSONRuleLocalAddressRangeEnd
            }

            # Interface Type
            if ($interfaces -ne 'notConfigured') {
                $JSONRuleInterface = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_interfacetypes",
                "settingInstanceTemplateReference": null,
                "choiceSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationChoiceSettingValue)",
                "choiceSettingCollectionValue": [
                  {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                    "settingValueTemplateReference": null,
                    "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_interfacetypes_all",
                    "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                    "children": []
                  }
                ]
            },

'@
            }

            # Package Family Name
            If (!([string]::IsNullOrEmpty($packageFamilyName))) {
                $JSONRulePackageFamily = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_packagefamilyname",
                "settingInstanceTemplateReference": null,
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "$packageFamilyName"
                }
            },

"@
            }

            # App File Path
            if (!([string]::IsNullOrEmpty($filePath))) {
                $JSONRuleFilePath = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_filepath",
                "settingInstanceTemplateReference": null,
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "$filePath"
                }
            },

"@
            }

            # Authorized Users
            if (!([string]::IsNullOrEmpty($authUsers))) {
                $JSONRuleAuthUsersStart = @'
                {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                    "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localuserauthorizedlist",
                    "settingInstanceTemplateReference": null,
                    "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                    "simpleSettingCollectionValue": [

'@
                $JSONAuthUsers = @()
                foreach ($AuthUser in $authUsers) {
                    # Last address in the set
                    if (($AuthUser -eq $authUsers[-1]) -or ($authUsers.count -eq '1')) {
                        $JSONRuleAuthUser = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$AuthUser"
                    }

"@
                    }
                    else {
                        $JSONRuleAuthUser = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$AuthUser"
                    },

"@
                    }
                    $JSONAuthUsers += $JSONRuleAuthUser
                }
                $JSONRuleAuthUsersEnd = @'

                ]
            },
'@
                $JSONRuleAuthUsers = $JSONRuleAuthUsersStart + $JSONAuthUsers + $JSONRuleAuthUsersEnd
            }

            # Remote Ports
            if (!([string]::IsNullOrEmpty($remotePorts))) {
                $JSONRuleRemotePortsStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_remoteportranges",
                "settingInstanceTemplateReference": null,
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONRemotePorts = @()
                foreach ($RemotePort in $remotePorts) {
                    # Last address in the set
                    if (($RemotePort -eq $remotePorts[-1]) -or ($remotePorts.count -eq '1')) {
                        $JSONRuleRemotePort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemotePort"
                    }

"@
                    }
                    else {
                        $JSONRuleRemotePort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemotePort"
                    },

"@
                    }
                    $JSONRemotePorts += $JSONRuleRemotePort
                }
                $JSONRuleRemotePortsEnd = @'

                ]
            },
'@
                $JSONRuleRemotePorts = $JSONRuleRemotePortsStart + $JSONRemotePorts + $JSONRuleRemotePortsEnd
            }


            # Firewall Profile
            if ($fwProfiles -ne 'notConfigured') {
                $JSONRuleFWProfileStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles",
                "settingInstanceTemplateReference": null,
                "choiceSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationChoiceSettingValue)",
                "choiceSettingCollectionValue": [

'@

                $JSONRuleFWProfileTypes = @()
                foreach ($FWProfile in $fwProfiles) {
                    Switch ($FWProfile) {
                        'domain' { $FWProfileNo = '1' }
                        'private' { $FWProfileNo = '2' }
                        'public' { $FWProfileNo = '4' }
                    }

                    if (($FWProfile -eq $fwProfiles[-1]) -or ($fwProfiles.count -eq '1')) {
                        $JSONRuleFWProfileType = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles_$FWProfileNo",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    }

"@
                    }
                    else {
                        $JSONRuleFWProfileType = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles_$FWProfileNo",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    },

"@
                    }

                    $JSONRuleFWProfileTypes += $JSONRuleFWProfileType
                }

                $JSONRuleFWProfileEnd = @'
                ]
            },

'@

                $JSONRuleFWProfile = $JSONRuleFWProfileStart + $JSONRuleFWProfileTypes + $JSONRuleFWProfileEnd
            }

            # Service Name
            if (!([string]::IsNullOrEmpty($service))) {
                $JSONRuleService = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_servicename",
                "settingInstanceTemplateReference": null,
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "$service"
                }
            },

"@
            }

            # Local Ports
            if ((!([string]::IsNullOrEmpty($localPorts)))) {
                $JSONRuleLocalPortsStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localportranges",
                "settingInstanceTemplateReference": null,
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONLocalPorts = @()
                foreach ($LocalPort in $localPorts) {
                    # Last address in the set
                    if (($LocalPort -eq $localPorts[-1]) -or ($localPorts.count -eq '1')) {
                        $JSONRuleLocalPort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalPort"
                    }

"@
                    }
                    else {
                        $JSONRuleLocalPort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalPort"
                    },

"@
                    }
                    $JSONLocalPorts += $JSONRuleLocalPort
                }
                $JSONRuleLocalPortsEnd = @'
                ]
            },

'@
                $JSONRuleLocalPorts = $JSONRuleLocalPortsStart + $JSONLocalPorts + $JSONRuleLocalPortsEnd
            }

            # Remote Address Ranges
            if ($useAnyRemoteAddresses -eq $false) {
                $JSONRuleRemoteAddressRangeStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_remoteaddressranges",
                "settingInstanceTemplateReference": null,
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONRemoteAddresses = @()
                foreach ($RemoteAddress in $remoteAddresses) {
                    # Last address in the set
                    if (($RemoteAddress -eq $remoteAddresses[-1]) -or ($remoteAddresses.count -eq '1')) {
                        $JSONRuleRemoteAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemoteAddress"
                    }

"@
                    }
                    else {
                        $JSONRuleRemoteAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemoteAddress"
                    },

"@
                    }
                    $JSONRemoteAddresses += $JSONRuleRemoteAddress
                }
                $JSONRuleRemoteAddressRangeEnd = @'
                ]
            },

'@
                $JSONRuleRemoteAddressRange = $JSONRuleRemoteAddressRangeStart + $JSONRemoteAddresses + $JSONRuleRemoteAddressRangeEnd
            }

            # Rule Action
            Switch ($action) {
                'allowed' { $ActionType = '1' }
                'blocked' { $ActionType = '0' }
            }
            $JSONRuleAction = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_action_type",
            "settingInstanceTemplateReference": null,
            "choiceSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
              "settingValueTemplateReference": null,
              "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_action_type_$ActionType",
              "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
              "children": []
            }
        },

"@

            # Rule Description
            $JSONRuleDescription = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_description",
            "settingInstanceTemplateReference": null,
            "simpleSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
              "settingValueTemplateReference": null,
              "value": "$description"
            }
        }

"@

            #Rule ending
            if ($rule -eq $rules[-1]) {
                $JSONRuleEnd = @'
                ]
            }

'@
            }
            else {
                $JSONRuleEnd = @'
                ]
            },

'@
            }

            # Build the subequent Rule and add to array
            $JSONRule = $JSONRuleStart + $JSONRuleName + $JSONRuleState + $JSONRuleDirection + $JSONRuleProtocol + $JSONRuleLocalAddressRange + $JSONRuleInterface + $JSONRulePackageFamily + $JSONRuleFilePath + $JSONRuleAuthUsers + $JSONRuleRemotePorts + $JSONRuleFWProfile + $JSONRuleService + $JSONRuleLocalPorts + $JSONRuleRemoteAddressRange + $JSONRuleAction + $JSONRuleDescription + $JSONRuleEnd
            $JSONAllRules += $JSONRule
        }
    }

    # Combining the all the JSON to form the Settings Catalog policy
    $JSONPolicy = $JSONPolicyStart + $JSONAllRules + $JSONPolicyEnd
    Write-Host "Creating new Settings Catalog Policy $newPolicyName" -ForegroundColor Cyan
    Try {
        New-DeviceSettingsCatalog -JSON $JSONPolicy
        Write-Host "Successfully created new Settings Catalog Policy $newPolicyName" -ForegroundColor Green
    }
    Catch {
        Write-Host "Unable to create new Settings Catalog Policy $newPolicyName, script will end." -ForegroundColor Red
        Break
    }

}