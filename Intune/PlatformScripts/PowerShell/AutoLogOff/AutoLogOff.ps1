[String]$stTaskName = 'Idle Logoff'
[String]$stDescription = 'Uses Screensaver and logon events to log off idle users.'
$stAction = New-ScheduledTaskAction -Execute 'C:\Windows\System32\shutdown.exe' -Argument '/l /f'
$stPrincipal = New-ScheduledTaskPrincipal -GroupId 'BUILTIN\Users'
$stSettings = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries

$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
$stTrigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
$stTrigger.Subscription = @'
<QueryList><Query Id="0" Path="System"><Select Path="Security">*[System[Provider[@Name='Microsoft Windows security auditing'] and EventID=4802]]</Select></Query></QueryList>
'@
$stTrigger.Enabled = $True

$stTask = New-ScheduledTask -Action $stAction -Trigger $stTrigger -Principal $stPrincipal -Settings $stSettings -Description $stDescription

Register-ScheduledTask -TaskName $stTaskName -InputObject $stTask -Force