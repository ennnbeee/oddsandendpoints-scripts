$avClient = 'Sophos Anti-Virus'
$avProduct = Get-CimInstance -Namespace 'root\SecurityCenter2' -Class AntiVirusProduct | Where-Object { $_.displayName -eq $avClient } | Select-Object -First 1
#$avProduct = Get-WmiObject -Namespace 'root\SecurityCenter2' -Class AntiVirusProduct | Where-Object { $_.displayName -eq $avClient } | Select-Object -First 1
$avSummary = New-Object -TypeName PSObject

If ($avProduct) {
    $hexProductState = [Convert]::ToString($avProduct.productState, 16).PadLeft(6, '0')
    $hexRealTimeProtection = $hexProductState.Substring(2, 2)
    $hexDefinitionStatus = $hexProductState.Substring(4, 2)

    $realTimeProtectionStatus = switch ($hexRealTimeProtection) {
        '00' { 'Off' }
        '01' { 'Expired' }
        '10' { 'On' }
        '11' { 'Snoozed' }
        default { 'Unknown' }
    }

    $definitionStatus = switch ($hexDefinitionStatus) {
        '00' { 'Up to Date' }
        '10' { 'Out of Date' }
        default { 'Unknown' }
    }

    $avSummary | Add-Member -MemberType NoteProperty -Name "$avClient" -Value $avProduct.displayName
    $avSummary | Add-Member -MemberType NoteProperty -Name "$avClient real time protection enabled" -Value $realTimeProtectionStatus
    $avSummary | Add-Member -MemberType NoteProperty -Name "$avClient definitions up-to-date" -Value $definitionStatus
}
Else {
    $avSummary | Add-Member -MemberType NoteProperty -Name "$avClient" -Value 'Error: No Antivirus product found'
    $avSummary | Add-Member -MemberType NoteProperty -Name "$avClient real time protection enabled" -Value 'Error: No Antivirus product found'
    $avSummary | Add-Member -MemberType NoteProperty -Name "$avClient definitions up-to-date" -Value 'Error: No Antivirus product found'
}

return $avSummary | ConvertTo-Json -Compress