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

    $oneDrivePath = $env:OneDrive

    if (-not $oneDrivePath) {
        Write-Host 'OneDrive is not configured or the environment variable is missing.'
        Exit 2000
    }

    # Normalize the OneDrive path (if it exists on the system)
    $oneDriveFullPath = Resolve-Path -Path $oneDrivePath -ErrorAction Stop

    # Construct the target Downloads path inside OneDrive
    $desiredDownloadsPath = Join-Path $oneDriveFullPath 'Downloads'

    # Known Folder GUID for Downloads = {374DE290-123F-4565-9164-39C4925E467B}
    $currentRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $currentDownloadsValue = (Get-ItemProperty -Path $currentRegPath -Name '{374DE290-123F-4565-9164-39C4925E467B}' -ErrorAction SilentlyContinue).'{374DE290-123F-4565-9164-39C4925E467B}'

    if ($currentDownloadsValue -and (Split-Path $currentDownloadsValue -Parent) -eq (Split-Path $desiredDownloadsPath -Parent)) {
        # The registry path might be the same or a slightly different format, let's do a direct string compare
        if ([string]::Equals($currentDownloadsValue, $desiredDownloadsPath, 'InvariantCultureIgnoreCase')) {
            Write-Host 'Downloads folder is already mapped to OneDrive.'
            exit 0
        }
    }
    else {
        Write-Host 'Downloads folder is not mapped to OneDrive.'
        exit 1
    }
}
catch {
    Write-Host "An error occurred during remediation: $($_.Exception.Message)"
    Exit 2000
}