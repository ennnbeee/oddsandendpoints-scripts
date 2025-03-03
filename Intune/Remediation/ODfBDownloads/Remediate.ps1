<#
.SYNOPSIS
  Detects and remediates the current user's Downloads folder to point to OneDrive.

.DESCRIPTION
  1. Checks if the current known folder for Downloads is already set to OneDrive\Downloads.
  2. If not, it moves existing files from the old Downloads folder, creates a OneDrive\Downloads folder if needed,
     and updates registry keys so that Windows recognizes the new location as "Downloads."
  3. Returns 0 (success) if already compliant or successfully remediated, 1 (error) if it fails.

.NOTES
  Run in user context, because it edits HKCU keys.
#>

try {
    # Normalize the OneDrive path (if it exists on the system)
    $oneDriveFullPath = Resolve-Path -Path $oneDrivePath -ErrorAction Stop

    # Construct the target Downloads path inside OneDrive
    $desiredDownloadsPath = Join-Path $oneDriveFullPath 'Downloads'

    # Create the OneDrive\Downloads directory if it does not exist
    if (-not (Test-Path $desiredDownloadsPath)) {
        New-Item -ItemType Directory -Path $desiredDownloadsPath -ErrorAction Stop | Out-Null
    }

    # Move existing files from old Downloads to new location (if old folder exists)
    $oldDownloadsPath = Join-Path $env:USERPROFILE 'Downloads'

    if (Test-Path $oldDownloadsPath) {
        $itemsToMove = Get-ChildItem -Path $oldDownloadsPath -Force -ErrorAction SilentlyContinue
        if ($itemsToMove) {
            Write-Host "Moving existing files from '$oldDownloadsPath' to '$desiredDownloadsPath'..."
            Move-Item -Path (Join-Path $oldDownloadsPath '*') -Destination $desiredDownloadsPath -Force -ErrorAction Stop
        }
    }

    # Update the registry to change the known folder path
    Set-ItemProperty -Path $currentRegPath -Name '{374DE290-123F-4565-9164-39C4925E467B}' -Value $desiredDownloadsPath

    # Also update the older 'Shell Folders' for compatibility
    $shellFoldersRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
    if (Test-Path $shellFoldersRegPath) {
        Set-ItemProperty -Path $shellFoldersRegPath -Name 'Downloads' -Value $desiredDownloadsPath
    }

    Write-Host 'Downloads folder successfully remapped to OneDrive.'
    exit 0
}
catch {
    Write-Host "An error occurred during remediation: $($_.Exception.Message)"
    exit 2000
}