. "$PSScriptRoot\IntuneFirewallRule.ps1"
. "$PSScriptRoot\ExportTo-ExcelFile.ps1"
. "$PSScriptRoot\..\Private\ConvertTo-IntuneFirewallRule-Helper.ps1"
. "$PSScriptRoot\..\Private\Process-IntuneFirewallRules.ps1"
. "$PSScriptRoot\..\Private\Send-Telemetry.ps1"
. "$PSScriptRoot\..\Private\Use-HelperFunctions.ps1"
. "$PSScriptRoot\..\Private\Strings.ps1"

function ConvertTo-IntuneFirewallRule {
    <#
    .SYNOPSIS
    Converts firewall rules to IntuneFirewallRule objects.

    .DESCRIPTION
    ConvertTo-IntuneFirewallRule takes a firewall rule object retrieved from Get-NetFirewallRule and converts it into an IntuneFirewallRule

    .EXAMPLE
    Get-NetFirewallRule | ConvertTo-IntuneFirewallRule
    Get-NetFirewallRule -PolicyStore RSOP | ConvertTo-IntuneFirewallRule -splitConflictingAttributes
    Get-NetFirewallRule -PolicyStore PersistentStore -PolicyStoreSourceType Local | ConvertTo-IntuneFirewallRule -splitConflictingAttributes -sendConvertTelemetry

    .PARAMETER incomingFirewallRules a stream of firewall rules to be processed and converted

    .NOTES
    If -splitConflictingAttributes is toggled, then firewall rules with multiple attributes of filePath, serviceName,
    or packageFamilyName will automatically be processed and split instead of prompting users to split the firewall rule

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/netsecurity/get-netfirewallrule?view=win10-ps#description

    .INPUTS
    Microsoft.Management.Infrastructure.CimInstance#root\StandardCimv2\MSFT_NetFirewallRule[]

    A stream of network firewall rules retrieved from the NetSecurity module

    .OUTPUTS
    IntuneFirewallRule[]

    A stream of exported firewall rules represented via the intermediate IntuneFirewallRule class
    #>

    [CmdletBinding()]
    Param(
        # For testing purposes, we do not require that the object is strongly typed;
        # however, it will fail in general other cases if it is not a firewall rule object
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $incomingFirewallRules,
        # If this flag is toggled, then firewall rules with multiple attributes of filePath, serviceName,
        # or packageFamilyName will automatically be processed and split instead of prompting users to split
        [switch] $doNotSplitConflictingAttributes,
        # If this flag is toggled, then telemetry is automatically sent to Microsoft.
        [switch] $sendConvertTelemetry,
        [switch] $DeviceConfiguration

    )

    Begin {
        $firewallRules = @()
        $rulesFailedToConvert = @()

    }

    Process {
        # Get-NetFirewallRule returns firewall rule objects pretty quickly,
        # so we can wait to pool the firewall rule objects into an array
        # to display the progress bars
        $firewallRules += $_
    }

    End {
        $intuneFirewallRuleObjects = @()
        $choice = ''
        $remainingFirewallRules = $firewallRules.Count

        ForEach ($firewallRule in $firewallRules) {
            Try {
                # remainingFirewallRules is decremented after displaying operation status
                $remainingFirewallRules = Show-OperationProgress `
                    -remainingObjects $remainingFirewallRules `
                    -totalObjects $firewallRules.Count `
                    -activityMessage $Strings.ConvertToIntuneFirewallRuleProgressMessage


                if ($DeviceConfiguration) {
                    # Processing firewall rule objects for endpoint security
                    $intuneFirewallRuleObject = New-IntuneFirewallRuleDC
                    # All of the attributes needed for firewall can be found, but they are typically scattered
                    # by multiple cmdlet filters. Look in the link provided for more information
                    $intuneFirewallRuleObject.displayName = Get-FirewallDisplayName $firewallRule
                    $intuneFirewallRuleObject.description = $firewallRule.description
                    $intuneFirewallRuleObject.packageFamilyName = Get-FirewallPackageFamilyName $firewallRule
                    $intuneFirewallRuleObject.filePath = Get-FirewallFilePath $firewallRule
                    $intuneFirewallRuleObject.serviceName = Get-FirewallServiceName $firewallRule
                    $intuneFirewallRuleObject.protocol = Get-FirewallProtocol $firewallRule
                    $intuneFirewallRuleObject.localPortRanges = Get-FirewallLocalPortRange $firewallRule
                    $intuneFirewallRuleObject.remotePortRanges = Get-FirewallRemotePortRange $firewallRule
                    $intuneFirewallRuleObject.localAddressRanges = Get-FirewallLocalAddressRange $firewallRule
                    $intuneFirewallRuleObject.remoteAddressRanges = Get-FirewallRemoteAddressRange $firewallRule
                    $intuneFirewallRuleObject.profileTypes = Get-FirewallProfileTypeDC $firewallRule.Profiles
                    $intuneFirewallRuleObject.action = Get-FirewallAction $firewallRule.Action
                    $intuneFirewallRuleObject.trafficDirection = Get-FirewallDirection $firewallRule.Direction
                    $intuneFirewallRuleObject.interfaceTypes = Get-FirewallInterfaceType $firewallRule
                    $intuneFirewallRuleObject.localUserAuthorizations = Get-FirewallLocalUserAuthorization $firewallRule
                    $intuneFirewallRuleObject.edgeTraversal = Get-FirewallEdgeTraversalPolicy $firewallRule

                    If (Test-IntuneFirewallRuleSplitDC -firewallObject $intuneFirewallRuleObject) {

                        $splitFirewallRuleChoice = Get-SplitIntuneFirewallRuleChoiceDC `
                            -splitConflictingAttributes $doNotsplitConflictingAttributes `
                            -firewallObject $intuneFirewallRuleObject
                        $splittedFirewallRuleObjects = Split-IntuneFirewallRuleDC -firewallObject $intuneFirewallRuleObject
                        Switch ($splitFirewallRuleChoice) {
                            $Strings.Yes { $intuneFirewallRuleObjects += $splittedFirewallRuleObjects }
                            $Strings.No { Throw $Strings.ConvertToIntuneFirewallRuleNoSplit }
                            $Strings.YesToAll {
                                $intuneFirewallRuleObjects += $splittedFirewallRuleObjects
                                # Allows future splitting operations to continue without user prompt
                                $doNotsplitConflictingAttributes = $false
                            }
                            $Strings.Continue { continue }
                        }
                    }
                    Else {
                        $intuneFirewallRuleObjects += $intuneFirewallRuleObject
                    }

                }
                else {
                    # Processing firewall rule objects for endpoint security
                    $intuneFirewallRuleObject = New-IntuneFirewallRule
                    # All of the attributes needed for firewall can be found, but they are typically scattered
                    # by multiple cmdlet filters. Look in the link provided for more information
                    $intuneFirewallRuleObject.displayName = Get-FirewallDisplayName $firewallRule
                    $intuneFirewallRuleObject.description = $firewallRule.description
                    $intuneFirewallRuleObject.packageFamilyName = Get-FirewallPackageFamilyName $firewallRule
                    $intuneFirewallRuleObject.filePath = Get-FirewallFilePath $firewallRule
                    $intuneFirewallRuleObject.serviceName = Get-FirewallServiceName $firewallRule
                    $intuneFirewallRuleObject.protocol = Get-FirewallProtocol $firewallRule
                    $intuneFirewallRuleObject.localPortRanges = Get-FirewallLocalPortRange $firewallRule
                    $intuneFirewallRuleObject.remotePortRanges = Get-FirewallRemotePortRange $firewallRule
                    $intuneFirewallRuleObject.actualLocalAddressRanges = Get-FirewallLocalAddressRange $firewallRule
                    $intuneFirewallRuleObject.actualRemoteAddressRanges = Get-FirewallRemoteAddressRange $firewallRule
                    $intuneFirewallRuleObject.profileTypes = Get-FirewallProfileType $firewallRule.Profiles
                    $intuneFirewallRuleObject.action = Get-FirewallAction $firewallRule.Action
                    $intuneFirewallRuleObject.trafficDirection = Get-FirewallDirection $firewallRule.Direction
                    $intuneFirewallRuleObject.interfaceTypes = Get-FirewallInterfaceType $firewallRule
                    $intuneFirewallRuleObject.localUserAuthorizations = Get-FirewallLocalUserAuthorization $firewallRule
                    $intuneFirewallRuleObject.useAnyLocalAddressRange = Get-useAnyLocalAddressRangeOption $firewallRule
                    $intuneFirewallRuleObject.useAnyRemoteAddressRange = Get-useAnyRemoteAddressRangeOption $firewallRule

                    # Check to see if a firewall rule needs to be split, and prompts the user if they want to split
                    If (Test-IntuneFirewallRuleSplit -firewallObject $intuneFirewallRuleObject) {

                        $splitFirewallRuleChoice = Get-SplitIntuneFirewallRuleChoice `
                            -splitConflictingAttributes $doNotSplitConflictingAttributes `
                            -firewallObject $intuneFirewallRuleObject
                        $splittedFirewallRuleObjects = Split-IntuneFirewallRule -firewallObject $intuneFirewallRuleObject
                        Switch ($splitFirewallRuleChoice) {
                            $Strings.Yes { $intuneFirewallRuleObjects += $splittedFirewallRuleObjects }
                            $Strings.No { Throw $Strings.ConvertToIntuneFirewallRuleNoSplit }
                            $Strings.YesToAll {
                                $intuneFirewallRuleObjects += $splittedFirewallRuleObjects
                                # Allows future splitting operations to continue without user prompt
                                $doNotSplitConflictingAttributes = $false
                            }
                            $Strings.Continue { continue }
                        }
                    }
                    Else {
                        $intuneFirewallRuleObjects += $intuneFirewallRuleObject
                    }
                }
            }
            Catch {

                <#$errorMessage = $_.ToString()
                $errorType = $_.Exception.GetType().ToString()
                # If the property does not exist, then the result is simply an empty string
                $errorFirewallRuleProperty = $_.Exception.firewallRuleProperty

                #-----------------------------------------------------------------------------------------
                if ($sendIntuneFirewallTelemetry) {
                    $choice = Get-IntuneFirewallRuleErrorTelemetryChoice -telemetryMessage $errorMessage `
                        -sendErrorTelemetryInitialized $sendIntuneFirewallTelemetry `
                        -telemetryExceptionType $errorType
                }
                else {
                    $choice = $Strings.Continue
                }
                #------------------------------------------------------------------------------------------
                # Choice is the index of the option

                Switch ($choice) {
                    $Strings.Yes {
                        Send-FailureToConvertToIntuneFirewallRuleTelemetry -data $errorMessage `
                            -errorType $errorType `
                            -firewallRuleProperty $errorFirewallRuleProperty
                    }
                    $Strings.No { Throw $Strings.ConvertToIntuneFirewallRuleNoException }
                    $Strings.YesToAll {
                        Send-FailureToConvertToIntuneFirewallRuleTelemetry -data $errorMessage `
                            -errorType $errorType `
                            -firewallRuleProperty $errorFirewallRuleProperty
                        $sendConvertTelemetry = $false
                    }
                    $Strings.Continue { continue }
                }#>
                # Add items that failed to be formatted to a collection of objects to be exported to an excel file
                $newExcelObject = New-Object -TypeName ExcelFormat
                $newExcelObject.displayName = $firewallRule.DisplayName
                $newExcelObject.description = $firewallRule.Description
                $newExcelObject.trafficDirection = $firewallRule.Direction
                $newExcelObject.action = $firewallRule.Action
                $newExcelObject.errorMessage = $errorMessage
                $rulesFailedToConvert += $newExcelObject
            }
        }
        #$dataTelemetry = '{0}/{1} Firewall rules were successfully converted to IntuneFirewallRuleObjects' -f ($firewallRules.Count - $rulesFailedToConvert.Count), $firewallRules.Count
        # Create an excel file with information about the items that where incompatible with intunes format
        Export-ExcelFile -fileName 'RuleError' -failedToConvert $rulesFailedToConvert
        Set-SummaryDetail -numberOfFirewallRules $firewallRules.Count -ConvertedRulesNumber ($firewallRules.Count - $rulesFailedToConvert.Count )
        #Send-SuccessCovertToIntuneFirewallRuleTelemetry -data $dataTelemetry
        return $intuneFirewallRuleObjects
    }
}