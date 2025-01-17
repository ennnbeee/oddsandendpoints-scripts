<#
.DESCRIPTION
	This script applies user based Windows Lanaguages upon logon
	When executed under SYSTEM authority a scheduled task is created to ensure recurring script execution on each user logon.

.NOTES
	Author: Nick Benton, https://memv.ennbee.uk
#>

[CmdletBinding()]
Param()
# Starts logging
Start-Transcript -Path $(Join-Path $env:temp 'WindowsLanguages-Run.log')

# Functions
#check if running as system
function Test-RunningAsSystem {
	[CmdletBinding()]
	param()
	process {
		return [bool]($(whoami -user) -match 'S-1-5-18')
	}
}

# Sets the Windows Languages
$LanguageList = New-WinUserLanguageList -Language 'en-GB'
$Languages = New-Object -TypeName System.Collections.ArrayList
$Languages.AddRange(@(
		'en-US',
		'ar-SA',
		'zh-HK',
		'zh-CN',
		'zh-TW',
		'el-GR',
		'he-IL',
		'ja-JP',
		'ko-KR',
		'zh-Hant-TW',
		'jp-JP',
		'am-ET',
		'Cy-az-AZ',
		'Lt-az-AZ',
		'fa-IR',
		'ka-GE',
		'el-GR',
		'gu-IN',
		'he-IL',
		'ru-KG',
		'ru-KZ',
		'mn-MN',
		'pa-IN',
		'ta-IN',
		'th-TH',
		'tr-TR',
		'ur-PK',
		'uz-Cyrl',
		'vi-VN'
	))

Foreach ($Language in $Languages) {
	$LanguageList.Add($Language)
}

Try {
	Set-WinUserLanguageList -LanguageList $LanguageList -Force
}
Catch {
	Write-Error "Unable to set the language list $($_.Exception.Message)"
}

Stop-Transcript

#!SCHTASKCOMESHERE!#
# If this script is running under system (IME) scheduled task is created (recurring)
if (Test-RunningAsSystem) {

	Start-Transcript -Path $(Join-Path -Path $env:temp -ChildPath 'WindowsLanguages-ST.log')
	Write-Output 'Running as System --> creating scheduled task which will run on user logon'

	# Get the current script path and content and save it to the client

	$currentScript = Get-Content -Path $($PSCommandPath)

	$schtaskScript = $currentScript[(0) .. ($currentScript.IndexOf('#!SCHTASKCOMESHERE!#') - 1)]

	$scriptSavePath = $(Join-Path -Path $env:ProgramData -ChildPath 'Intune-Helper\Windows-Languages')

	if (-not (Test-Path $scriptSavePath)) {

		New-Item -ItemType Directory -Path $scriptSavePath -Force
	}

	$scriptSavePathName = 'Set-WindowsLanguages.ps1'

	$scriptPath = $(Join-Path -Path $scriptSavePath -ChildPath $scriptSavePathName)

	$schtaskScript | Out-File -FilePath $scriptPath -Force

	# Create dummy vbscript to hide PowerShell Window popping up at logon
	
	$vbsDummyScript = "
	Dim shell,fso,file

	Set shell=CreateObject(`"WScript.Shell`")
	Set fso=CreateObject(`"Scripting.FileSystemObject`")

	strPath=WScript.Arguments.Item(0)

	If fso.FileExists(strPath) Then
		set file=fso.GetFile(strPath)
		strCMD=`"powershell -nologo -executionpolicy ByPass -command `" & Chr(34) & `"&{`" &_
		file.ShortPath & `"}`" & Chr(34)
		shell.Run strCMD,0
	End If
	"

	$scriptSavePathName = 'WindowsLanguages-VBSHelper.vbs'

	$dummyScriptPath = $(Join-Path -Path $scriptSavePath -ChildPath $scriptSavePathName)

	$vbsDummyScript | Out-File -FilePath $dummyScriptPath -Force

	$wscriptPath = Join-Path $env:SystemRoot -ChildPath 'System32\wscript.exe'

	# Register a scheduled task to run for all users and execute the script on logon

	$schtaskName = 'Intune Helper - Windows Languages'
	$schtaskDescription = 'Applies Windows Languages using a PowerShell script.'

	$trigger = New-ScheduledTaskTrigger -AtLogOn
	#Execute task in users context
	$principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -Id 'Author'
	#call the vbscript helper and pass the PosH script as argument
	$action = New-ScheduledTaskAction -Execute $wscriptPath -Argument "`"$dummyScriptPath`" `"$scriptPath`""
	$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

	$null = Register-ScheduledTask -TaskName $schtaskName -Trigger $trigger -Action $action -Principal $principal -Settings $settings -Description $schtaskDescription -Force

	Start-ScheduledTask -TaskName $schtaskName

	Stop-Transcript
}

