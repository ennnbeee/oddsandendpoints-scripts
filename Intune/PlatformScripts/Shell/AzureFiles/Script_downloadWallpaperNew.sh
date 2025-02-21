#!/bin/bash
#set -x

# Define variables
wallpaperFile=logo-aad-bg-dark.png
wallpaperUrl=

# standard variables
scriptName="SetWallpaper"
wallpaperDir="/Library/Desktop"
logandmetaDir="/Library/Logs/Microsoft/IntuneScripts/$scriptName"
log="$logandmetaDir/$scriptName.log"

## Check if the log directory has been created
if [ -d $logandmetaDir ]; then
    ## Already created
    echo "# $(date) | Log directory already exists - $logandmetaDir"
else
    ## Creating Metadirectory
    echo "# $(date) | creating log directory - $logandmetaDir"
    mkdir -p $logandmetaDir
fi

# start logging
exec 1>>$log 2>&1

echo ""
echo "##############################################################"
echo "# $(date) | Starting download of Desktop Wallpaper"
echo "############################################################"
echo ""

if [ -d $wallpaperDir ]; then
    echo "$(date) | Wallpaper dir [$wallpaperDir] already exists"
else
    echo "$(date) | Creating [$wallpaperDir]"
    mkdir -p $wallpaperDir
fi

echo "$(date) | Downloading Wallpaper file [$wallpaperFile] from [$wallpaperUrl] to [$wallpaperDir/$wallpaperFile]"
if [[ $wallpaperUrl == http* ]]; then

    curl -L -o $wallpaperDir/$wallpaperFile $wallpaperUrl/$wallpaperFile
    if [ "$?" = "0" ]; then
        echo "$(date) | Wallpaper file [$wallpaperFile] from [$wallpaperUrl] downloaded to [$wallpaperDir/$wallpaperFile]"
        killall Dock
        exit 0
    else
        echo "$(date) | Failed to download wallpaper file [$wallpaperFile] from [$wallpaperUrl]"
        exit 1
    fi
elif [[ $wallpaperUrl == smb* ]]; then
    smbMount=$(mktemp -d)
    mount_smbfs "$wallpaperUrl" "$smbMount"
    cp "$smbMount/$wallpaperFile" "$wallpaperDir"

    if [ "$?" = "0" ]; then
        echo "$(date) | Wallpaper file [$wallpaperFile] from [$wallpaperUrl] downloaded to [$wallpaperDir/$wallpaperFile]"
        killall Dock
        echo "$(date) | Removing mount $smbMount"
        umount "$smbMount"
        echo "$(date) | Removing $smbMount"
        rm -rf "$smbMount"
        exit 0
    else
        echo "$(date) | Failed to download wallpaper image from [$wallpaperUrl]"
        echo "$(date) | Removing mount $smbMount"
        umount "$smbMount"
        echo "$(date) | Removing $smbMount"
        rm -rf "$smbMount"
        exit 1
    fi
else
    echo "$(date) | Unsupported protocol for [$wallpaperUrl]"
    exit 1
fi
