$ready = 0
$dsRegCmd = dsregcmd /status
$dsRegOutput = New-Object -TypeName PSObject

$dsRegCmd | Select-String -Pattern ' *[A-z]+ : [A-z]+ *' | ForEach-Object {
    Add-Member -InputObject $dsRegOutput -MemberType NoteProperty -Name (([String]$_).Trim() -split ' : ')[0] -Value (([String]$_).Trim() -split ' : ')[1]
}

if ($dsRegOutput.AzureAdJoined -eq 'YES') {
    $ready++
}

if ($ready -gt 0) {
    Write-Output Ready
}
