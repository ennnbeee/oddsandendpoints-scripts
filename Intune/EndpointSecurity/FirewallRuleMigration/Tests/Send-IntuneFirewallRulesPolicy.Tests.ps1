. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Public\Send-IntuneFirewallRulesPolicy.ps1"
. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\Strings.ps1"

Describe 'Send-IntuneFirewallRulesPolicy' {
    Context 'Empty base case' {
        It 'Should run nothing if given empty profiles' {
            Mock Invoke-MgGraphRequest
            @() | Send-IntuneFirewallRulesPolicy
            Assert-MockCalled Invoke-MgGraphRequest -Times 0
        }
    }

    Context 'Running with one profile' {
        It 'Should run Invoke-MgGraphRequest once if given 1 <= x <= 150' {
            Mock Invoke-MgGraphRequest
            @(1..10) | Send-IntuneFirewallRulesPolicy
            Assert-MockCalled Invoke-MgGraphRequest -Times 1 -Exactly
        }
    }

    Context 'Running with two profiles' {
        It 'Should run Invoke-MgGraphRequest twice if given 151 <= x <= 300' {
            Mock Invoke-MgGraphRequest
            @(1..151) | Send-IntuneFirewallRulesPolicy
            Assert-MockCalled Invoke-MgGraphRequest -Times 2 -Exactly
        }
    }

    Context 'Running with five profiles' {
        It 'Should run Invoke-MgGraphRequest 5 times' {
            Mock Invoke-MgGraphRequest
            @(1..(150 * 5)) | Send-IntuneFirewallRulesPolicy
            Assert-MockCalled Invoke-MgGraphRequest -Times 5 -Exactly
        }
    }

    Context 'Telemetry test cases' {
        Mock Invoke-MgGraphRequest -MockWith { Throw 'foo' }

        It "Should send graph telemetry if given '$($Strings.Yes)'" {
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.Yes }
            Mock Send-IntuneFirewallGraphTelemetry
            @(1) | Send-IntuneFirewallRulesPolicy
            Assert-MockCalled Send-IntuneFirewallGraphTelemetry -Times 1 -Exactly
        }

        It "Should send graph telemetry if given '$($Strings.No)'" {
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.No }
            Mock Send-IntuneFirewallGraphTelemetry
            { @(1) | Send-IntuneFirewallRulesPolicy } | Should -Throw 'User aborted error handling for Send-IntuneFirewallRulesPolicy'
        }

        It "Should send graph telemetry if given '$($Strings.Continue)'" {
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.Continue }
            Mock Send-IntuneFirewallGraphTelemetry
            @(1) | Send-IntuneFirewallRulesPolicy
        }
    }

    # Separate context to avoid colliding mocks with "Yes" test case
    Context "Telemetry '$($Strings.YesToAll)'" {
        Mock Invoke-MgGraphRequest -MockWith { Throw 'foo' }

        It "Should send graph telemetry if given '$($Strings.YesToAll)'" {
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.YesToAll }
            Mock Send-IntuneFirewallGraphTelemetry
            @(1) | Send-IntuneFirewallRulesPolicy
            Assert-MockCalled Send-IntuneFirewallGraphTelemetry -Times 1 -Exactly
        }
    }

    # Separate context to avoid colliding mocks with "Yes" test case
    Context "Telemetry '$($Strings.Continue)'" {
        Mock Invoke-MgGraphRequest -MockWith { Throw 'foo' }

        It "Should send graph telemetry if given '$($Strings.Continue)'" {
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.Continue }
            Mock Send-IntuneFirewallGraphTelemetry
            @(1) | Send-IntuneFirewallRulesPolicy
            Assert-MockCalled Send-IntuneFirewallGraphTelemetry -Times 0 -Exactly
        }
    }
}