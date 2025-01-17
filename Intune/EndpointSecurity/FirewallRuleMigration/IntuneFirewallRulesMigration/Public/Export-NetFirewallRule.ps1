. "$PSScriptRoot\ConvertTo-IntuneFirewallRule.ps1"
. "$PSScriptRoot\Get-SampleFirewallData.ps1"
. "$PSScriptRoot\..\Private\Strings.ps1"

function Export-NetFirewallRule {
    <#
    .SYNOPSIS
    Exports network firewall rules found on this host into Intune firewall rules.

    .DESCRIPTION
    Export-NetFirewallRule will export all network firewall rules found on the host and convert them into an
    intermediate IntuneFirewallRule object

    .EXAMPLE
    Export-NetFirewallRule
    Export-NetFirewallRule -PolicyStoreSource GroupPolicy
    Export-NetFirewallRule -PolicyStoreSource All
    Export-NetFirewallRule -splitConflictingAttributes -sendExportTelemetry

    .NOTES
    Export-NetFirewallRule is a wrapper for the cmdlet call to Get-NetFirewallRule piped to ConvertTo-IntuneFirewallRule.

    If -splitConflictingAttributes is toggled, then firewall rules with multiple attributes of filePath, serviceName,
    or packageFamilyName will automatically be processed and split instead of prompting users to split the firewall rule

    If -sendExportTelemetry is toggled, then error messages encountered will automatically be sent to Microsoft and the
    tool will continue processing net firewall rules.

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/netsecurity/get-netfirewallrule?view=win10-ps#description

    .OUTPUTS
    IntuneFirewallRule[]

    A stream of exported firewall rules represented via the intermediate IntuneFirewallRule class
    #>
    [CmdletBinding()]
    Param(
        #Defines the profile Name for the set of rules to be imported
        [Parameter(Mandatory = $true)]
        [String]
        $ProfileName,
        # Defines the policy store source to pull net firewall rules from.
        [ValidateSet('GroupPolicy', 'All')]
        [string] $PolicyStoreSource = 'GroupPolicy',
        # If this switch is toggled, only the firewall rules that are currently enabled are imported
        [boolean]
        $EnabledOnly = $True,
        # This determines if we are running a test version or a full importation. The default value is full. The test version imports only 20 rules
        [ValidateSet('Full', 'Test')]
        [String]
        $Mode = 'Full',
        [bool]
        $CheckProfileName = $true,
        # If this flag is toggled, then firewall rules with multiple attributes of filePath, serviceName,
        # or packageFamilyName will not automatically be processed and split and the users will be prompted users to split
        [switch] $doNotsplitConflictingAttributes,
        # If this flag is toggled, then telemetry is automatically sent to Microsoft.
        [switch] $sendExportTelemetry,
        # If this flag is toogled, then firewall rules would be imported to Device Configuration else it would be import to Endpoint Security
        [Switch]
        $DeviceConfiguration



    )
    if ($CheckProfileName -eq $true) {

        try {

            $json = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/deviceManagement/intents?$filter=templateId%20eq%20%274b219836-f2b1-46c6-954d-4cd2f4128676%27%20or%20templateId%20eq%20%274356d05c-a4ab-4a07-9ece-739f7c792910%27%20or%20templateId%20eq%20%275340aa10-47a8-4e67-893f-690984e4d5da%27'
            $profiles = $json.value
            $profileNameExist = $true
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
        }
        catch {
            $errorMessage = $_.ToString()

            Write-Error $errorMessage
            return
        }

    }


    $sendExportTelemetry = $False

    # The default behavior for Get-NetFirewallRule is to retrieve all WDFWAS firewall rules
    return $(Get-FirewallData -Enabled:$EnabledOnly -Mode:$Mode -PolicyStoreSource:$PolicyStoreSource | ConvertTo-IntuneFirewallRule `
            -doNotsplitConflictingAttributes:$doNotsplitConflictingAttributes `
            -DeviceConfiguration:$DeviceConfiguration `
        | Send-IntuneFirewallRulesPolicy `
            -migratedProfileName:$ProfileName `
            -DeviceConfiguration:$DeviceConfiguration
    )

}