# Assigned variables
$contentName = 'CONTENTNAME'
$targetFolder = 'C:\Tools'

# Generated variables
$logFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\$contentName`_Uninstall.log"

# Delete any existing logfile if it exists
If (Test-Path $logFile) {
    Remove-Item $logFile -Force -ErrorAction SilentlyContinue -Confirm:$false
}

Function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $TimeGenerated = $(Get-Date -UFormat '%D %T')
    $Line = "$TimeGenerated : $Message"
    Add-Content -Value $Line -Path $logFile -Encoding Ascii
}

Write-Log 'Starting Content Copy Uninstallation'

# Make sure target folder exists
If (!(Test-Path $targetFolder)) {
    Write-Log "Target folder $targetFolder does not exist, do nothing"
}
else {
    Write-Log "About to delete $targetFolder"
    try {
        Remove-Item -Path $targetFolder -Recurse -Force -ErrorAction Stop
        Write-Log "$targetFolder successfully deleted"
        Exit 0
    }
    catch {
        Write-Log "Failed to delete TargetFolder. Error is: $($_.Exception.Message))"
        Exit 1
    }
}