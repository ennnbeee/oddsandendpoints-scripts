. "$PSScriptRoot\Use-HelperFunctions.ps1"
. "$PSScriptRoot\Strings.ps1"
function Send-FailureToConvertToIntuneFirewallRuleTelemetry {
    <#
    .SYNOPSIS
    Sends telemetry regarding converting firewall rules to IntuneFirewallRule objects out to the Intune team at Microsoft.

    .DESCRIPTION
    Send-FailureToConvertToIntuneFirewallRuleTelemetry will send the provided string to the Intune team for diagnosing exceptions encountered by the user.
    Sending telemetry is completely optional and users should be prompted to send telemetry when encountering exceptions.

    .EXAMPLE
    Send-FailureToConvertToIntuneFirewallRuleTelemetry -data "Hello, world!"

    .PARAMETER data a string representing the data to be sent to Intune
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $data,
        [string]
        $errorType,
        [string]
        $firewallRuleProperty
    )
    Send-FailureTelemetry -data $data `
        -category $Strings.TelemetryConvertToIntuneFirewallRule `
        -errorType $errorType `
        -firewallRuleProperty $firewallRuleProperty
}
function Send-SuccessCovertToIntuneFirewallRuleTelemetry {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $data
    )
    Send-SuccessTelemetry -data $data `
        -category $Strings.TelemetrySuccessfullyConvertedToIntuneFirewallRule `


}

function Send-SuccessIntuneFirewallGraphTelemetry {
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $data
    )
    Send-SuccessTelemetry -data $data `
        -category $Strings.TelemetryIntuneFirewallRuleGraphImportSuccess

}

function Send-IntuneFirewallGraphTelemetry {
    <#
    .SYNOPSIS
    Sends Intune Firewall telemetry data regarding the graph out to the Intune team at Microsoft.

    .DESCRIPTION
    Send-IntuneFirewallGraphTelemetry will send the provided string to the Intune team for diagnosing exceptions encountered by the user.
    Sending telemetry is completely optional and users should be prompted to send telemetry when encountering exceptions.

    .EXAMPLE
    Send-IntuneFirewallGraphTelemetry -data "Hello, world!"

    .PARAMETER data a string representing the data to be sent to Intune
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $data
    )
    Send-FailureTelemetry -data $data `
        -category $Strings.TelemetryIntuneFirewallRuleGraph
}

function Send-FailureTelemetry {
    <#
    .SYNOPSIS
    Sends telemetry data regarding the provided string out to the Intune team at Microsoft.

    .DESCRIPTION
    Send-FailureTelemetry will send the provided string to the Intune team for diagnosing exceptions encountered by the user.
    Sending telemetry is completely optional and users should be prompted to send telemetry when encountering exceptions.

    .EXAMPLE
    Send-FailureTelemetry -data $error.Exception.ToString() -category "ConvertToIntuneFirewalRule"

    .PARAMETER data a string representing the data to be sent to Intune
    .PARAMETER category the category of the error that is sent
    .PARAMETER errorType the type of error encountered
    .PARAMETER firewallRuleProperty the property that the error occurred in
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $data,
        [Parameter(Mandatory = $true)]
        [String]
        $category,
        [String]
        $errorType,
        [String]
        $firewallRuleProperty
    )

    Initialize-Telemetry
    $eventProperties = New-Object Microsoft.Applications.Telemetry.EventProperties
    $eventProperties.Name = $category

    $propertiesToSend = @{$Strings.Message = $data; $Strings.ErrorType = $errorType; $Strings.FirewallRuleProperty = $firewallRuleProperty }
    ForEach ($property in $propertiesToSend.GetEnumerator()) {
        # Output needs to be suppressed to avoid polluting the output stream
        Write-Debug $($eventProperties.SetProperty($property.Name, $property.Value))
    }

    $logger = [Microsoft.Applications.Telemetry.Server.LogManager]::GetLogger()
    # LogFailure() has several identification parameters that are not necessary for our purposes since
    # all telemetry sent are errors anyways
    $logger.LogFailure($Strings.TelemetrySignature, $Strings.TelemetryError, $category, $Strings.TelemetryId, $eventProperties)
}
function Send-SuccessTelemetry {

    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $data,
        [Parameter(Mandatory = $true)]
        [String]
        $category
    )

    Initialize-Telemetry
    $eventProperties = New-Object Microsoft.Applications.Telemetry.EventProperties
    $eventProperties.Name = $category

    $propertiesToSend = @{$Strings.Message = $data; }
    ForEach ($property in $propertiesToSend.GetEnumerator()) {
        # Output needs to be suppressed to avoid polluting the output stream
        Write-Debug $($eventProperties.SetProperty($property.Name, $property.Value))
    }

    $logger = [Microsoft.Applications.Telemetry.Server.LogManager]::GetLogger()
    # LogEvent() sends telemetry for an event that occured. Since the [Microsoft.Applications.Telemetry.Server.LogManager] class
    # does not have a function to send telemetry for success. LogEvent works

    $logger.LogEvent($eventProperties)
}
function Get-IntuneFirewallRuleErrorTelemetryChoice {
    <#
    .SYNOPSIS
    Prompts the user to provide a choice of sending telemetry data when an error is provided.

    .DESCRIPTION
    Get-IntuneFirewallRuleErrorTelemetryChoice will notify the user that an error has occurred, and
    provide them with the choice of sending the error message to Microsoft (Yes, No, Yes To All, Continue).

    .EXAMPLE
    Get-IntuneFirewallRuleErrorTelemetryChoice -telemetryMessage "Crashed" -sendErrorTelemetryInitialized $true

    .PARAMETER telemetryMessage a string representing the error message to be sent to Intune
    .PARAMETER sendErrorTelemetryInitialized flag indicating whether or not a user wants to send telemetry
    .PARAMETER telemetryExceptionType the type of exception returned from the error
    .PARAMETER firewallRuleProperty the firewall rule property that the error occurred in
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [String]
        $telemetryMessage,
        [boolean]
        $sendErrorTelemetryInitialized,
        [string]
        $telemetryExceptionType,
        [string]
        $firewallRuleProperty
    )
    # If passed a true flag, avoid the prompt altogether
    If ($sendErrorTelemetryInitialized) {
        return $Strings.Yes
    }

    $errorTitle = $Strings.TelemetryErrorTitle
    $additionalErrorInformation = ''
    If ($telemetryExceptionType) {
        $additionalErrorInformation += $Strings.TelemetryErrorExceptionType -f $telemetryExceptionType
    }
    If ($firewallRuleProperty) {
        $additionalErrorInformation += $Strings.TelemetryErrorFirewallRuleProperty -f $firewallRuleProperty
    }
    $errorMessage = $Strings.TelemetryErrorMessage -f ($telemetryMessage, $additionalErrorInformation)
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', $Strings.TelemetrySendErrorYes
    $no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', $Strings.TelemetrySendErrorNo
    $all = New-Object System.Management.Automation.Host.ChoiceDescription 'Yes to &All', $Strings.TelemetrySendErrorYesToAll
    $continue = New-Object System.Management.Automation.Host.ChoiceDescription '&Continue', $Strings.TelemetrySendErrorContinue
    $errorOptions = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $all, $continue)

    $choice = Get-UserPrompt -promptTitle $errorTitle `
        -promptMessage $errorMessage `
        -promptOptions $errorOptions `
        -defaultOption 0

    # Choice is the index of the option
    Switch ($choice) {
        0 { return $Strings.Yes }
        1 { return $Strings.No }
        2 { return $Strings.YesToAll }
        3 { return $Strings.Continue }
    }
}

# Telemetry instrumentation starter code. This code should not be touched.
function Initialize-Telemetry {
    If (-not $script:TelemetryIsInitialized) {
        Try {
            $telemetryBinDir = "$PSScriptRoot\Telemetry"

            # All of these values need to be sent out to null to avoid polluting the output stream
            Write-Debug $([Reflection.Assembly]::LoadFile([System.IO.Path]::Combine($telemetryBinDir, 'Microsoft.Applications.Telemetry.dll')))
            Write-Debug $([Reflection.Assembly]::LoadFile([System.IO.Path]::Combine($telemetryBinDir, 'Microsoft.Applications.Telemetry.Server.dll')))
            Write-Debug $([Reflection.Assembly]::LoadFile([System.IO.Path]::Combine($telemetryBinDir, 'Microsoft.Bond.Interfaces.dll')))
            Write-Debug $([Reflection.Assembly]::LoadFile([System.IO.Path]::Combine($telemetryBinDir, 'Microsoft.Bond.dll')))
            Write-Debug $([Microsoft.Applications.Telemetry.Server.LogManager]::Initialize('b1351bbab261472b8362d4fe3439e1d6-b8cb7bd6-994f-458b-bb03-bb31aee684a6-7725'))

            # It's not possible to unload the telemetry assemblies during the PowerShell session, but it is possible
            # to unload the assemblies when unloading the app domain. As a result, we can push the unloading event
            # to happen when the app domain unloading event handler happens (after closing the PowerShell Session)
            $AppDomain = [System.AppDomain]::CurrentDomain;
            $Action = { [Microsoft.Applications.Telemetry.Desktop.LogManager]::FlushAndTearDown(); }

            # Output needs to be suppressed to avoid polluting the output stream
            Write-Debug $(Register-ObjectEvent -InputObject $AppDomain -EventName DomainUnload -Action $Action -SourceIdentifier DomainUnload)
            $script:TelemetryIsInitialized = $true
        }
        Catch {
            # There were mentions of the telemetry being saved to local storage, but
            # I could not find where the events were saved, so I left out any mentions
            # of the locally cached events
            Write-Error $($Strings.TelemetryInitializeTelemetryError -f $_)
        }
    }
}