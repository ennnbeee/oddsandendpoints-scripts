# Assigned variables
$contentName = 'CONTENTNAME'
$contentVersion = '1.0'
$targetFolder = 'C:\Tools'

# Generated variables
$contentTag = $($contentName + '_' + $contentVersion +'.tag')
$logFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\$contentName`_Install.log"
$sourceFolder = $PSScriptRoot

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

Write-Log 'Starting Content Copy Installation'

# Make sure target folder exists
If (!(Test-Path $targetFolder)) {
    Write-Log "Target folder $targetFolder does not exist, creating it"
    New-Item -Path $targetFolder -ItemType Directory -Force
}

# Copy the tools
Write-Log "About to copy contents from $sourceFolder to $targetFolder"
try {
    Copy-Item -Path "$sourceFolder\*" -Destination $targetFolder -Recurse -Force -ErrorAction Stop
    New-Item -Path $targetFolder -ItemType File -Name $contentTag -Force
    Write-Log "Contents of $sourceFolder successfully copied to $targetFolder"
    Exit 0
}
catch {
    Write-Log "Failed to copy $sourceFolder to $targetFolder. Error is: $($_.Exception.Message))"
    Exit 1
}

