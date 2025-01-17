. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\Use-HelperFunctions.ps1"
. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\Strings.ps1"

Describe 'Show-OperationProgress' {
    It 'Should call Write-progress and return a decremented remaining value' {
        Mock Write-Progress
        Show-OperationProgress -remainingObjects 10 -totalObjects 10 -activityMessage 'foo' | Should -Be 9
        Assert-MockCalled Write-Progress
    }

    It 'Should throw an exception if given non-positive total objects' {
        For ($i = -10; $i -le 0; $i++) {
            { Show-OperationProgress `
                    -remainingObjects 0 `
                    -totalObjects $i `
                    -activityMessage 'foo' } | Should -Throw $Strings.ShowOperationProgressException
        }
    }
}