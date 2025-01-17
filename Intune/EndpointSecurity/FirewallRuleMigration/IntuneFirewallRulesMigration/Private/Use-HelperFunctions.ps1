. "$PSScriptRoot\Strings.ps1"
# This file represents several utility functions that do not belong to telemetry, exporting, or importing alone.

function Show-OperationProgress {
    <#
    .SYNOPSIS
    Displays a progress bar regarding how much work has been completed.

    .DESCRIPTION
    Show-OperationProgress does two things: It will display the progress of the work that has already been done, and also return a number
    stating how many objects are left to process

    .EXAMPLE
    Show-OperationProgress -remainingObjects 14 -totalObjects 28 -activityMessage "foo"

    .PARAMETER remainingObjects an int representing how many objects are left to process
    .PARAMETER totalObjects an int representing how many objects need to be processed in total
    .PARAMETER activityMessage a string representing what ac tivity is currently being done

    .NOTES
    Show-OperationProgress writes the progress to a bar on the host console.

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/write-progress?view=powershell-6

    .OUTPUTS
    Int32

    The remaining amount of objects that need to be processed after this operation.
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [int]
        $remainingObjects,
        [Parameter(Mandatory = $true)]
        [int]
        $totalObjects,
        [Parameter(Mandatory = $true)]
        [string]
        $activityMessage
    )

    # The function should never be called with 0 or less objects because there needs to be objects to process
    If ($totalObjects -le 0) {
        Throw $Strings.ShowOperationProgressException
    }

    $completedObjects = $totalObjects - $remainingObjects
    # Write-Progress will normally take an int value, but it is possible to send this value as a truncated float
    $percentComplete = [Math]::Round($completedObjects / $totalObjects * 100, 2)
    Write-Progress -Activity $activityMessage `
        -Status $($Strings.OperationStatus -f $completedObjects, $totalObjects, $percentComplete) `
        -PercentComplete $percentComplete
    # Since this represents a single operation, we decrement the remaining objects to work once.
    return $remainingObjects - 1
}

function Get-UserPrompt {
    <#
    .SYNOPSIS
    Wrapper function for getting user prompt data.

    .DESCRIPTION
    Get-UserPrompt is a wrapper function that wraps around $host.ui.PromptForChoice, as Pester does not currently support the mocking of such methods.

    .EXAMPLE
    Get-UserPrompt -promptTitle "title" -promptMessage "description" -promptOptions $promptOptions -defaultOption 0

    .PARAMETER promptTitle The title of the prompt
    .PARAMETER promptMessage The message of the prompt
    .PARAMETER promptOptions a set of choices that users have the option of picking from
    .PARAMETER defaultOption an integer representing the index of the option to be selected by default

    .OUTPUTS
    Int32

    The index of the option provided from the given set of choices
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [string]
        $promptTitle,

        [Parameter(Mandatory = $true)]
        [string]
        $promptMessage,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Host.ChoiceDescription[]]
        $promptOptions,

        [Parameter(Mandatory = $true)]
        [int]
        $defaultOption
    )
    return $host.ui.PromptForChoice($promptTitle, $promptMessage, $promptOptions, $defaultOption)
}