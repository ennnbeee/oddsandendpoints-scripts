$defenderFolder = "$env:ProgramData\Microsoft\Windows Defender\Platform\"
$defenderVersionFolder = Get-ChildItem -Path $defenderFolder | Sort-Object LastWriteTime | Select-Object -last 1

$MpCmdRun = $defenderVersionFolder.FullName + '\MpCmdRun.exe'

Start-Process -FilePath $MpCmdRun -ArgumentList '-h'

$defenderStatus = Get-MpComputerStatus
$defenderStatus.DefenderSignaturesOutOfDate