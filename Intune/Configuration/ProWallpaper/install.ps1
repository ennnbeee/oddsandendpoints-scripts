$packageName = 'CompanyBranding'
$packageVersion = 1

# Set image file names for desktop background and lock screen
# leave blank if you wish not to set either of one
$imageWallpaper = 'logo-bg-dark.png'
$imageLockScreen = 'logo-bg-light.png'

Start-Transcript -Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\$packageName-install.log" -Force
$ErrorActionPreference = 'Stop'

# Set variables for registry key path and names of registry values to be modified
$regKeyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$desktopPath = 'DesktopImagePath'
$desktopStatus = 'DesktopImageStatus'
$desktopUrl = 'DesktopImageUrl'
$lockScreenPath = 'LockScreenImagePath'
$lockScreenStatus = 'LockScreenImageStatus'
$lockScreenUrl = 'LockScreenImageUrl'
$statusValue = '1'

# local path of images
$imageWallpaperLocal = 'C:\Windows\System32\Desktop.jpg'
$imageLockScreenLocal = 'C:\Windows\System32\Lockscreen.jpg'

# Check whether both image file variables have values, output warning message and exit if either is missing
if (!$imageLockScreen -and !$imageWallpaper) {
    Write-Warning 'Either $imageWallpaper or $imageLockScreen must has a value.'
}
else {
    # Check whether registry key path exists, create it if it does not
    if (!(Test-Path $regKeyPath)) {
        Write-Host "Creating registry path: $($regKeyPath)."
        New-Item -Path $regKeyPath -Force
    }
    if ($imageLockScreen) {
        Write-Host "Copy lock screen ""$($imageLockScreen)"" to ""$($imageLockScreenLocal)"""
        Copy-Item ".\Data\$imageLockScreen" $imageLockScreenLocal -Force
        Write-Host 'Creating reg keys for lock screen'
        New-ItemProperty -Path $regKeyPath -Name $lockScreenStatus -Value $statusValue -PropertyType DWORD -Force
        New-ItemProperty -Path $regKeyPath -Name $lockScreenPath -Value $imageLockScreenLocal -PropertyType STRING -Force
        New-ItemProperty -Path $regKeyPath -Name $lockScreenUrl -Value $imageLockScreenLocal -PropertyType STRING -Force
    }
    if ($imageWallpaper) {
        Write-Host "Copy wallpaper ""$($imageWallpaper)"" to ""$($imageWallpaperLocal)"""
        Copy-Item ".\Data\$imageWallpaper" $imageWallpaperLocal -Force
        Write-Host 'Creating reg keys for wallpaper'
        New-ItemProperty -Path $regKeyPath -Name $desktopStatus -Value $statusValue -PropertyType DWORD -Force
        New-ItemProperty -Path $regKeyPath -Name $desktopPath -Value $imageWallpaperLocal -PropertyType STRING -Force
        New-ItemProperty -Path $regKeyPath -Name $desktopUrl -Value $imageWallpaperLocal -PropertyType STRING -Force
    }
}


New-Item -Path "C:\ProgramData\scloud\Validation\$packageName" -ItemType 'file' -Force -Value $packageVersion

Stop-Transcript
