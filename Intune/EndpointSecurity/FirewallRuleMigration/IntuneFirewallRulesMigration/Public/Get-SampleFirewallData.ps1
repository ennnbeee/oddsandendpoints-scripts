function Get-FirewallData {
    <#
    .SYNOPSIS
    Gets a sample collection of firewall rules

    .DESCRIPTION
    Get-SampleFirewallData allows the developer specify the number of firewall rules to be imported
    This is for testing purposes

    .EXAMPLE
    Get-SampleFirewallData


    .OUTPUTS
    System.Array[]
    #>
    param(
        # If this switch is toggled only the firewall rules that are currently enabled would be imported
        [Parameter(Mandatory = $false)]
        [Switch]
        $Enabled,
        # Defines the policy store source to pull net firewall rules from.
        [ValidateSet('GroupPolicy', 'All')]
        [string] $PolicyStoreSource = 'All',
        # This determines if we are running a test version or a full importation. The default value is full. The test version imports only 20 rules
        [ValidateSet('Full', 'Test')]
        [String]
        $Mode
    )
    $allFirewallRules = @()
    switch ($PolicyStoreSource) {
        'All' {
            $allFirewallRules = Get-NetFirewallRule
            if ($allFirewallRules) {
                if ($Enabled) {
                    $allFirewallRules = Get-NetFirewallRule -Enabled True
                }
                else {
                    $allFirewallRules = Get-NetFirewallRule
                }

            }
            else {
                Write-Host 'No Rules were found'
                return
            }
        }
        'GroupPolicy' {
            $allFirewallRules = Get-NetFirewallRule -PolicyStore RSOP
            if ($allFirewallRules) {
                if ($Enabled) {
                    $allFirewallRules = Get-NetFirewallRule -PolicyStore RSOP -Enabled True
                }
                else {
                    $allFirewallRules = Get-NetFirewallRule -PolicyStore RSOP
                }
            }
            else {
                Write-Host $('No {0} rules were found' -f $PolicyStoreSource)
                return
            }
        }
        default { Throw $('Given invalid policy store source: {0}' -f $PolicyStoreSource) }
    }

    switch ($Mode) {
        'Test' {

            Write-Host "`rYou are now in Test Mode. Only 20 firewall rules would be sent...`r"
            if ($allFirewallRules.Count -ge 20) {
                return $allFirewallRules[0..20]
            }
            else {
                return $allFirewallRules
            }
        }
        'Full' {
            return $allFirewallRules
        }
        Default {
            Write-Host 'The mode you have selected is not available. Importing all' $allFirewallRules.Count 'firewall rules.'
            return $allFirewallRules
        }
    }

}