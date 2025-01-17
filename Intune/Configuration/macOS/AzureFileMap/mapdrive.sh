#!/bin/bash
currentUser=$USER
azureFilesShareName='share'
azureFilesAccount='memvennbee'
azureFilesSharePath="smb://$azureFilesAccount:$azureFilesKey@$azureFilesAccount.file.core.windows.net/$azureFileShareName"

out='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>URL</key>
    <string>smb:'$azureFilesSharePath'</string>
</dict>
</plist>'
echo $out > ~/$azureFilesShareName.inetloc

/Library/Application Support/$azureFilesAccount/seticon -d /Library/Application Support/Q-Drive/Q-drive.icns /Users/$USER/$azureFilesShareName.inetloc

/Library/Application Support/$azureFilesAccount/dockutil --add ~/$azureFilesShareName.inetloc

mkdir /Volumes/$currentUser
mount_smbfs $azureFilesSharePath /Volumes/$currentUser

exit 0