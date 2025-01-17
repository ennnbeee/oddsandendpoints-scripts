. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Public\ConvertTo-IntuneFirewallRule.ps1"
. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\ConvertTo-IntuneFirewallRule-Helper.ps1"
. "$PSScriptRoot\..\IntuneFirewallRulesMigration\Private\Strings.ps1"

Describe 'ConvertTo-IntuneFirewallRule' {
    Context 'ConvertTo-IntuneFirewallRule expected cases' {
        It 'Should return empty array if no rules found' {
            Mock -CommandName 'Get-NetFirewallRule' -MockWith { return @() }
            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 0 -Because 'Get-NetFirewallRule returned empty array, nothing to process'
        }
    }

    Context 'Splitting Firewall Rule tests' {
        Mock Get-FirewallPackageFamilyName -MockWith { return 'foo' }
        Mock Get-FirewallFilePath -MockWith { return 'foo' }
        Mock Get-FirewallServiceName -MockWith { return 'foo' }
        Mock Get-FirewallProtocol -MockWith { return 0 }
        Mock Get-FirewallLocalPortRange -MockWith { return @() }
        Mock Get-FirewallRemotePortRange -MockWith { return @() }
        Mock Get-FirewallLocalAddressRange -MockWith { return @() }
        Mock Get-FirewallRemoteAddressRange -MockWith { return @() }
        Mock Get-FirewallProfileType -MockWith { return 2 }
        Mock Get-FirewallAction -MockWith { return 'foo' }
        Mock Get-FirewallDirection -MockWith { return 'foo' }
        Mock Get-FirewallInterfaceType -MockWith { return 'foo' }
        Mock Get-FirewallLocalUserAuthorization -MockWith { return 'foo' }
        Mock Get-FirewallEdgeTraversalPolicy -MockWith { return 'foo' }

        # There is an array of only one object provided.
        $mockFirewallObject = @{displayName = 'foo'; description = 'foo'; Profiles = 2; Action = 2; Direction = 2 }
        Mock Get-NetFirewallRule -MockWith { return @($mockFirewallObject) }

        It 'Should skip splitting prompt if no split is determined necessary and just add object as normal' {
            Mock Test-IntuneFirewallRuleSplit -MockWith { return $false }
            Mock Get-SplitIntuneFirewallRuleChoice
            Mock Split-IntuneFirewallRule

            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 1
            Assert-MockCalled Get-SplitIntuneFirewallRuleChoice -Exactly 0
            Assert-MockCalled Split-IntuneFirewallRule -Exactly 0
        }

        It "Should export two objects if user selected '$($Strings.Yes)' and two objects were returned from Split-IntuneFirewallChoice" {
            Mock Test-IntuneFirewallRuleSplit -MockWith { return $true }
            Mock Get-SplitIntuneFirewallRuleChoice -MockWith { return $Strings.Yes }
            Mock Split-IntuneFirewallRule -MockWith { @(1, 2) }

            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 2
        }

        It "Should call Get-IntuneFirewallRuleErrorTelemetryChoice if user selected '$($Strings.No)'" {
            # Returns 'Continue' to avoid having to handle other side effects from the selection
            Mock Test-IntuneFirewallRuleSplit -MockWith { return $true }
            Mock Get-SplitIntuneFirewallRuleChoice -MockWith { return $Strings.No }
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.Continue }

            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule
            Assert-MockCalled Get-IntuneFirewallRuleErrorTelemetryChoice -Exactly 1
        }

        It "Should export two objects if user selected '$($Strings.YesToAll)' and two objects were returned from Split-IntuneFirewallChoice" {
            Mock Test-IntuneFirewallRuleSplit -MockWith { return $true }
            Mock Get-SplitIntuneFirewallRuleChoice -MockWith { return $Strings.YesToAll }
            Mock Split-IntuneFirewallRule -MockWith { @(1, 2) }

            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 2
        }

        It "Should export no objects if user selected '$($Strings.Continue)'" {
            Mock Test-IntuneFirewallRuleSplit -MockWith { return $true }
            Mock Get-SplitIntuneFirewallRuleChoice -MockWith { return $Strings.Continue }
            Mock Split-IntuneFirewallRule -MockWith { @(1, 2) }

            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 0
        }
    }

    Context 'Telemetry test cases' {
        Mock Get-FirewallPackageFamilyName -MockWith { return 'foo' }
        Mock Get-FirewallFilePath -MockWith { return 'foo' }
        Mock Get-FirewallServiceName -MockWith { return 'foo' }
        Mock Get-FirewallProtocol -MockWith { return 0 }
        Mock Get-FirewallLocalPortRange -MockWith { return @() }
        Mock Get-FirewallRemotePortRange -MockWith { return @() }
        Mock Get-FirewallLocalAddressRange -MockWith { return @() }
        Mock Get-FirewallRemoteAddressRange -MockWith { return @() }
        Mock Get-FirewallProfileType -MockWith { return 2 }
        Mock Get-FirewallAction -MockWith { return 'foo' }
        Mock Get-FirewallDirection -MockWith { return 'foo' }
        Mock Get-FirewallInterfaceType -MockWith { return 'foo' }
        Mock Get-FirewallLocalUserAuthorization -MockWith { return 'foo' }
        Mock Get-FirewallEdgeTraversalPolicy -MockWith { return 'foo' }

        # There is an array of only one object provided.
        $mockFirewallObject = @{displayName = 'foo'; description = 'foo'; Profiles = 2; Action = 2; Direction = 2 }
        Mock Get-NetFirewallRule -MockWith { return @($mockFirewallObject) }

        It "Should give ConvertToIntuneFirewallRule telemetry if given '$($Strings.Yes)'" {
            Mock Test-IntuneFirewallRuleSplit -MockWith { Throw 'Yes Error' }
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.Yes }
            Mock Send-ConvertToIntuneFirewallRuleTelemetry

            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 0
            Assert-MockCalled Send-ConvertToIntuneFirewallRuleTelemetry -Times 1 -Exactly
        }

        It "Should throw an error if given '$($Strings.No)'" {
            Mock Test-IntuneFirewallRuleSplit -MockWith { Throw 'foo' }
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.No }

            { Get-NetFirewallRule | ConvertTo-IntuneFirewallRule } | Should -Throw $Strings.ConvertToIntuneFirewallRuleNoException
        }
    }

    # Separate context to avoid colliding mocks with "Yes" test case
    Context "Telemetry '$($Strings.YesToAll)'" {
        Mock Get-FirewallPackageFamilyName -MockWith { Throw 'foo' }

        # There is an array of only one object provided.
        $mockFirewallObject = @{displayName = 'foo'; description = 'foo'; Profiles = 2; Action = 2; Direction = 2 }
        Mock Get-NetFirewallRule -MockWith { return @($mockFirewallObject) }

        It "Should give ConvertToIntuneFirewallRule telemetry if given '$($Strings.YesToAll)'" {
            Mock Test-IntuneFirewallRuleSplit -MockWith { Throw 'Yes To All Error' }
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.YesToAll }
            Mock Send-ConvertToIntuneFirewallRuleTelemetry

            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 0
            Assert-MockCalled Send-ConvertToIntuneFirewallRuleTelemetry -Times 1 -Exactly
        }
    }

    # Separate context to avoid colliding mocks with "Yes" test case
    Context "Telemetry '$($Strings.Continue)'" {
        Mock Get-FirewallPackageFamilyName -MockWith { Throw 'foo' }

        # There is an array of only one object provided.
        $mockFirewallObject = @{displayName = 'foo'; description = 'foo'; Profiles = 2; Action = 2; Direction = 2 }
        Mock Get-NetFirewallRule -MockWith { return @($mockFirewallObject) }

        It "Should give ConvertToIntuneFirewallRule telemetry if given '$($Strings.Continue)'" {
            Mock Test-IntuneFirewallRuleSplit -MockWith { Throw 'Continue Error' }
            Mock Get-IntuneFirewallRuleErrorTelemetryChoice -MockWith { return $Strings.Continue }
            Mock Send-ConvertToIntuneFirewallRuleTelemetry

            Get-NetFirewallRule | ConvertTo-IntuneFirewallRule | Should -HaveCount 0
            Assert-MockCalled Send-ConvertToIntuneFirewallRuleTelemetry -Times 0 -Exactly
        }
    }

    Context 'ConvertTo-IntuneFirewallRule error cases' {
        It 'Should result in an error if Get-NetFirewallRule results in an error' {
            Mock -CommandName 'Get-NetFirewallRule' { Throw 'some error' }
            { Get-NetFirewallRule | ConvertTo-IntuneFirewallRule } | Should Throw 'some error'
        }
    }
}

Describe 'Get-FirewallDisplayName' {
    It 'Should return a string if given a string' {
        $mockFirewallObject = @{displayName = 'foo' }
        Get-FirewallDisplayName -firewallObject $mockFirewallObject | Should -Be 'foo'
    }

    It "Should return a filtered if given a string with '/' or '|'" {
        $mockFirewallObject = @{displayName = 'foo|/|/bar/|/|baz' }
        Get-FirewallDisplayName -firewallObject $mockFirewallObject | Should -Be 'foo____bar____baz'
    }

    It "Should return a formatted, truncated string if the string is >200 characters long and user selected 'Yes'" {
        $mockFirewallObject = @{displayName = '|/|/' * 100 }
        Mock Get-UserPrompt -MockWith { return 0 }

        $expectedString = '_' * 200
        Get-FirewallDisplayName -firewallObject $mockFirewallObject | Should -Be $expectedString
    }

    It "Should throw an exception if string > 200 characters long and user selected 'No'" {
        $mockFirewallObject = @{displayName = 'A' * 201 }
        Mock Get-UserPrompt -MockWith { return 1 }

        { Get-FirewallDisplayName -firewallObject $mockFirewallObject } | Should -Throw $Strings.FirewallRuleDisplayNameException
    }

    It "Should prompt users to enter new display name if string > 200 characters long and user selected 'Rename'" {
        $mockFirewallObject = @{displayName = 'A' * 201 }
        Mock Get-UserPrompt -MockWith { return 2 }
        Mock Read-Host -MockWith { return 'foo' }

        Get-FirewallDisplayName -firewallObject $mockFirewallObject | Should -Be 'foo'
        Assert-MockCalled Read-Host -Exactly 1
    }
}

Describe 'Get-FirewallPackageFamilyName' {
    It "Should return NULL if the object's package name is empty" {
        Mock -CommandName 'Get-NetFirewallApplicationFilterWrapper' -MockWith { return @{Package = '' } }
        Get-FirewallPackageFamilyName 'someObject' | Should -Be $null
    }

    It 'Should return the lookup values for any values found in the hash table' {
        # Since packageSid is populated prior to testing, we can verify that the hash table keys are returned
        ForEach ($keyValuePair in $packageSidLookup.GetEnumerator()) {
            Mock Get-NetFirewallApplicationFilterWrapper -MockWith { return @{Package = $keyValuePair.Key } }
            Get-FirewallPackageFamilyName 'someObject' | Should -Be $keyValuePair.Value
        }
    }

    It "Should prompt user to enter new package family name if entry is found 'Yes'" {
        Mock -CommandName 'Get-NetFirewallApplicationFilterWrapper' -MockWith { return @{Package = 'fooBarBaz' } }
        Mock Get-UserPrompt -MockWith { return 0 }
        Mock Read-Host -MockWith { return 'foo' }
        Get-FirewallPackageFamilyName 'someObject' | Should -Be 'foo'
    }

    It "Should throw error if entry is found and user selected 'No'" {
        Mock -CommandName 'Get-NetFirewallApplicationFilterWrapper' -MockWith { return @{Package = 'fooBarBaz' } }
        Mock Get-UserPrompt -MockWith { return 1 }
        { Get-FirewallPackageFamilyName 'someObject' } | Should -Throw $Strings.FirewallRulePackageFamilyNameException
    }
}

Describe 'Get-FirewallFilePath' {
    It "Should return NULL if the file path is 'Any'" {
        Mock -CommandName 'Get-NetFirewallApplicationFilterWrapper' -MockWith { return @{Program = $Strings.Any } }
        Get-FirewallFilePath 'someObject' | Should -Be $null
    }

    It "Should return 'foo' if the object's program name is foo" {
        Mock -CommandName 'Get-NetFirewallApplicationFilterWrapper' -MockWith { return @{Program = 'foo' } }
        Get-FirewallFilePath 'someObject' | Should -Be 'foo'
    }

    It 'Should throw an error if Get-NetFirewallApplicationFilter throws an error' {
        Mock -CommandName Get-NetFirewallApplicationFilterWrapper { Throw 'foo' }
        { Get-FirewallFilePath 'someObject' } | Should Throw
    }
}

Describe 'Get-FirewallService' {
    It 'Should return a string value' {
        Mock -CommandName 'Get-NetFirewallServiceFilterWrapper' { return @{Service = 'foo' } }
        Get-FirewallServiceName 'someObject' | Should -Be 'foo'
    }

    It "Should return an empty string if given '$($Strings.Any)'" {
        Mock -CommandName 'Get-NetFirewallServiceFilterWrapper' { return @{Service = $Strings.Any } }
        Get-FirewallServiceName 'someObject' | Should -Be $null
    }
}

Describe 'Get-FirewallProtocol' {
    It "Should return '1' if the protocol is 'ICMPv4'" {
        Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{Protocol = 'ICMPv4' } }
        Get-FirewallProtocol 'someObject' | Should -Be 1
    }

    It "Should return '6' if the protocol is 'TCP'" {
        Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{Protocol = 'TCP' } }
        Get-FirewallProtocol 'someObject' | Should -Be 6
    }

    It "Should return '17' if the protocol is 'UDP'" {
        Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{Protocol = 'UDP' } }
        Get-FirewallProtocol 'someObject' | Should -Be 17
    }

    It "Should return '58' if the protocol is 'ICMPv6'" {
        Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{Protocol = 'ICMPv6' } }
        Get-FirewallProtocol 'someObject' | Should -Be 58
    }

    It "Should return NULL if the protocol is 'Any'" {
        Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{Protocol = $Strings.Any } }
        Get-FirewallProtocol 'someObject' | Should -Be $null
    }

    It 'Should return a parsed integer if given a string of a number (from 0 - 255)' {
        # All ports from 0 - 255 inclusive are valid ports, the graph will reject any other number
        For ($i = 0; $i -le 255; $i++) {
            Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{Protocol = [string]$i } }
            Get-FirewallProtocol 'someObject' | Should -Be $i
        }
    }

    It 'Should crash if a string not belonging to ICMP, UDP or TCP appears' {
        Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{Protocol = 'foo' } }
        { Get-FirewallProtocol 'someObject' } | Should -Throw $Strings.FirewallRuleProtocolException.trim('{0}')
    }
}

Describe 'Get-FirewallLocalPortRange' {
    Context 'String handling cases' {
        It 'Should return NULL if given null' {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{ } }
            Get-FirewallLocalPortRange 'someObject' | Should -Be $null
        }

        It "Should return empty array if given '$($Strings.Any)'" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{LocalPort = $Strings.Any } }
            Get-FirewallLocalPortRange 'someObject' | Should -BeNullOrEmpty
        }

        It 'Should return the same string number if given a string number' {
            For ($i = 0; $i -le 10; $i++) {
                Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{LocalPort = [string]$i } }
                Get-FirewallLocalPortRange 'someObject' | Should -Be ([string]$i)
            }
        }

        It "Should return '123-456' if given '123-456'" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{LocalPort = '123-456' } }
            Get-FirewallLocalPortRange 'someObject' | Should -Be '123-456'
        }
    }

    Context 'Array handling case' {
        It "Should return '()' if given empty array" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{LocalPort = @() } }
            Get-FirewallLocalPortRange 'someObject' | Should -Be @()
        }

        It "Should return ('1', '2', '3', '123-456') if given an array with elements ('1', '2', '3', '123-456')" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{LocalPort = @('1', '2', '3', '123-456') } }
            Get-FirewallLocalPortRange 'someObject' | Should -Be @('1', '2', '3', '123-456')
        }
    }

    Context 'Error handling case' {
        It 'Should throw an error if given an integer' {
            Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{LocalPort = 2 } }
            { Get-FirewallLocalPortRange 'someObject' } | Should -Throw $Strings.FirewallRulePortException.trim('{0}')
        }

        It "Should throw if given '-123'" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{LocalPort = '-123' } }
            { Get-FirewallLocalPortRange 'someObject' } | Should -Throw $Strings.FirewallRulePortRangeException.trim('{0}')
        }

        It 'should throw if given a mix of letters and numbers' {
            Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{LocalPort = '12a3' } }
            { Get-FirewallLocalPortRange 'someObject' } | Should -Throw $Strings.FirewallRulePortRangeException.trim('{0}')
        }
    }
}

Describe 'Get-FirewallRemotePortRange' {
    Context 'String handling cases' {
        It 'Should return NULL if given null' {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{ } }
            Get-FirewallRemotePortRange 'someObject' | Should -Be $null
        }

        It "Should return empty array if given '$($Strings.Any)'" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{RemotePort = $Strings.Any } }
            Get-FirewallRemotePortRange 'someObject' | Should -BeNullOrEmpty
        }

        It 'Should return the same string number if given a string number' {
            For ($i = 0; $i -le 10; $i++) {
                Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{RemotePort = [string]$i } }
                Get-FirewallRemotePortRange 'someObject' | Should -Be ([string]$i)
            }
        }

        It "Should return '123-456' if given '123-456'" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{RemotePort = '123-456' } }
            Get-FirewallRemotePortRange 'someObject' | Should -Be '123-456'
        }
    }

    Context 'Array handling case' {
        It "Should return '()' if given empty array" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{RemotePort = @() } }
            Get-FirewallRemotePortRange 'someObject' | Should -Be @()
        }

        It "Should return ('1', '2', '3', '123-456') if given an array with elements ('1', '2', '3', '123-456')" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper -MockWith { return @{RemotePort = @('1', '2', '3', '123-456') } }
            Get-FirewallRemotePortRange 'someObject' | Should -Be @('1', '2', '3', '123-456')
        }
    }

    Context 'Error handling case' {
        It 'Should throw an error if given an integer' {
            Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{RemotePort = 2 } }
            { Get-FirewallRemotePortRange 'someObject' } | Should -Throw $Strings.FirewallRulePortException.trim('{0}')
        }

        It "Should throw if given '-123'" {
            Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{RemotePort = '-123' } }
            { Get-FirewallRemotePortRange 'someObject' } | Should -Throw $Strings.FirewallRulePortRangeException.trim('{0}')
        }

        It 'should throw if given a mix of letters and numbers' {
            Mock -CommandName Get-NetFirewallPortFilterWrapper { return @{RemotePort = '12a3' } }
            { Get-FirewallRemotePortRange 'someObject' } | Should -Throw $Strings.FirewallRulePortRangeException.trim('{0}')
        }
    }
}

Describe 'Get-FirewallLocalAddressRange' {
    It "Should return NULL if given '$($Strings.Any)'" {
        Mock -CommandName Get-NetFirewallAddressFilterWrapper -MockWith { return @{LocalAddress = $Strings.Any } }
        Get-FirewallLocalAddressRange 'someObject' | Should -BeNullOrEmpty
    }

    It "Should throw an error if given 'PlayToDevice'" {
        Mock -CommandName Get-NetFirewallAddressFilterWrapper -MockWith { return @{LocalAddress = 'PlayToDevice' } }
        { Get-FirewallLocalAddressRange 'someObject' } | Should -Throw $Strings.FirewallRuleAddressRangePlayToDeviceException
    }

    It 'Should return random given string' {
        Mock -CommandName Get-NetFirewallAddressFilterWrapper -MockWith { return @{LocalAddress = 'foo' } }
        Get-FirewallLocalAddressRange 'someObject' | Should -Be 'foo'
    }
}

Describe 'Get-FirewallRemoteAddressRange' {
    It "Should return NULL if given '$($Strings.Any)'" {
        Mock -CommandName Get-NetFirewallAddressFilterWrapper -MockWith { return @{RemoteAddress = $Strings.Any } }
        Get-FirewallRemoteAddressRange 'someObject' | Should -Be $null
    }

    It "Should throw an error if given 'PlayToDevice'" {
        Mock -CommandName Get-NetFirewallAddressFilterWrapper -MockWith { return @{RemoteAddress = 'PlayToDevice' } }
        { Get-FirewallRemoteAddressRange 'someObject' } | Should -Throw $Strings.FirewallRuleAddressRangePlayToDeviceException
    }

    It 'Should return random given string' {
        Mock -CommandName Get-NetFirewallAddressFilterWrapper -MockWith { return @{RemoteAddress = 'foo' } }
        Get-FirewallRemoteAddressRange 'someObject' | Should -Be 'foo'
    }
}

Describe 'Get-FirewallAction' {
    It "Should return 'allowed' if given 2" {
        Get-FirewallAction 2 | Should -Be 'allowed'
    }

    It "Should return 'blocked' if given 4" {
        Get-FirewallAction 4 | Should -Be 'blocked'
    }

    It 'Should throw unsupported message if given 3' {
        { Get-FirewallAction 3 } | Should -Throw $Strings.FirewallRuleActionAllowBypassException
    }

    It 'Should throw if given anything else' {
        # The string needs to be cut off past the '{0}' part in the format string
        $index = $Strings.FirewallRuleActionException.IndexOf("'")
        { Get-FirewallAction 0 } | Should -Throw $Strings.FirewallRuleActionException.Substring(0, $index)
        { Get-FirewallAction 5 } | Should -Throw $Strings.FirewallRuleActionException.Substring(0, $index)
    }
}

Describe 'Get-FirewallDirection' {
    It "Should return 'in' if given 1" {
        Get-FirewallDirection 1 | Should -Be 'in'
    }

    It "Should return 'out' if given 2" {
        Get-FirewallDirection 2 | Should -Be 'out'
    }

    It 'Should throw if given anything else' {
        { Get-FirewallDirection 0 } | Should -Throw
        { Get-FirewallDirection 3 } | Should -Throw
    }
}

Describe 'Get-FirewallInterfaceTypes' {
    It "Should return NULL if given 'Any' " {
        Mock -CommandName Get-NetFirewallInterfaceTypeFilterWrapper -MockWith { return @{ InterfaceType = 'Any' } }
        Get-FirewallInterfaceType 'someObject' | Should -BeNullOrEmpty
    }

    It "Should return 'lan' if given 'LocalAccess'" {
        Mock -CommandName Get-NetFirewallInterfaceTypeFilterWrapper -MockWith { return @{ InterfaceType = 'LocalAccess' } }
        Get-FirewallInterfaceType 'someObject' | Should -Be 'lan'
    }

    It "Should return 'wireless' if given 'WirelessAccess'" {
        Mock -CommandName Get-NetFirewallInterfaceTypeFilterWrapper -MockWith { return @{ InterfaceType = 'WirelessAccess' } }
        Get-FirewallInterfaceType 'someObject' | Should -Be 'wireless'
    }

    It "Should return 'remoteAccess' if given 'RemoteAcccess'" {
        Mock -CommandName Get-NetFirewallInterfaceTypeFilterWrapper -MockWith { return @{ InterfaceType = 'RemoteAccess' } }
        Get-FirewallInterfaceType 'someObject' | Should -Be 'remoteAccess'
    }

    It "Should return 'notConfigured' if given anything else" {
        Mock -CommandName Get-NetFirewallInterfaceTypeFilterWrapper -MockWith { return @{ InterfaceType = 3 } }
        { Get-FirewallInterfaceType 'someObject' } | Should -Throw
    }
}

Describe 'Get-FirewallLocalUserAuthorization' {
    It 'Should return a string if given a string' {
        Mock -CommandName Get-NetFirewallSecurityFilterWrapper -MockWith { return @{ LocalUser = 'foo' } }
        Get-FirewallLocalUserAuthorization 'someObject' | Should -Be 'foo'
    }

    It "Should return '' if given ''" {
        Mock -CommandName Get-NetFirewallSecurityFilterWrapper -MockWith { return @{ LocalUser = '' } }
        Get-FirewallLocalUserAuthorization 'someObject' | Should -Be ''
    }

    It "Should return NULL if given 'Any'" {
        Mock -CommandName Get-NetFirewallSecurityFilterWrapper -MockWith { return @{ LocalUser = 'Any' } }
        Get-FirewallLocalUserAuthorization 'someObject' | Should -Be $null
    }
}

Describe 'Get-FirewallEdgeTraversalPolicy' {
    Context 'Normal cases' {
        It "Should return 'blocked' if given inbound direction and 0 for policy" {
            Mock Get-FirewallDirection -MockWith { return 'in' }
            Get-FirewallEdgeTraversalPolicy @{ EdgeTraversalPolicy = 0 } | Should -Be 'blocked'
        }

        It "Should return 'allowed' if given inbound direction and 1 for policy" {
            Mock Get-FirewallDirection -MockWith { return 'in' }
            Get-FirewallEdgeTraversalPolicy @{ EdgeTraversalPolicy = 1 } | Should -Be 'allowed'
        }

        It 'Should return NULL if given outbound direction and 0 for policy' {
            Mock Get-FirewallDirection -MockWith { return 'out' }
            Get-FirewallEdgeTraversalPolicy @{ EdgeTraversalPolicy = 0 } | Should -BeNullOrEmpty
        }
    }

    Context 'Error cases' {
        It 'Should throw if given inbound direction and 2 for policy' {
            Mock Get-FirewallDirection -MockWith { return 'in' }
            { Get-FirewallEdgeTraversalPolicy @{ EdgeTraversalPolicy = 2 } } | Should -Throw
        }

        It 'Should throw if given outbound direction and n for policy' {
            For ($i = 1; $i -lt 10; $i++) {
                Mock Get-FirewallDirection -MockWith { return 'out' }
                { Get-FirewallEdgeTraversalPolicy @{ EdgeTraversalPolicy = $i } } | Should -Throw
            }
        }

        It 'Should throw if given a different direction than in or out' {
            Mock Get-FirewallDirection -MockWith { return 'foo' }
            { Get-FirewallEdgeTraversalPolicy @{ EdgeTraversalPolicy = 0 } } | Should -Throw
        }
    }
}

Describe 'Get-FirewallProfileType' {
    It "Should return 'notConfigured' if given 0" {
        Get-FirewallProfileType 0 | Should -Be $null
    }

    It "Should return 'domain' if given 1" {
        Get-FirewallProfileType 1 | Should -Be 'domain'
    }

    It "Should return 'private' if given 2" {
        Get-FirewallProfileType 2 | Should -Be 'private'
    }

    It "Should return 'domain,private' if given 3" {
        Get-FirewallProfileType 3 | Should -Be 'domain, private'
    }

    It "Should return 'public' if given 4" {
        Get-FirewallProfileType 4 | Should -Be 'public'
    }

    It "Should return 'domain,public' if given 5" {
        Get-FirewallProfileType 5 | Should -Be 'domain, public'
    }

    It "Should return 'private,public' if given 6" {
        Get-FirewallProfileType 6 | Should -Be 'private, public'
    }

    It "Should return 'domain,private,public' if given 7" {
        Get-FirewallProfileType 7 | Should -Be 'domain, private, public'
    }

    It 'Should throw an error if not within the intervals [0, 7]' {
        { Get-FirewallProfileType 8 } | Should -Throw
    }
}