#!/bin/zsh
#set -x

# Define variables
appname="CIS-L1-SystemSettings-General"
logandmetadir="/Library/Logs/Microsoft/IntuneScripts/$appname"
log="$logandmetadir/$appname.log"

# Check if the log directory has been created
if [ -d $logandmetadir ]; then
    # Already created
    echo "$(date) | Log directory already exists - $logandmetadir"
else
    # Creating Metadirectory
    echo "$(date) | creating log directory - $logandmetadir"
    mkdir -p $logandmetadir
fi

# Disables CD or DVD Sharing
DisableCDOrDVDSharing() {
    /bin/launchctl disable system/com.apple.ODSAgent
    echo "$(date) | DVD or CD Sharing is disabled or already disabled. Closing script..."
}

# Disables Remote Login
DisableRemoteLogin() {
    echo Yes | /usr/sbin/systemsetup -setremotelogin off
    echo ""
    echo "$(date) | Remote Login is now disabled or already disabled. Closing script..."
}

# Disables Remote Management
DisableRemoteManagement() {
    /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -stop
    echo "$(date) | Remote Management will be fully disabled after reboot or is already disabled. Closing script..."
}

# Disables Remote Apple Events
DisableRemoteAppleEvents() {
    /usr/sbin/systemsetup -setremoteappleevents off 2>/dev/null
    echo "$(date) | Remote Apple Events is now disabled or already disabled. Closing script..."
}

# Start logging
exec &> >(tee -a "$log")

# Begin Script Body
echo ""
echo "##############################################################"
echo "# $(date) | Starting running of script $appname"
echo "############################################################"
echo ""

# Run function
DisableCDOrDVDSharing

DisableRemoteLogin

DisableRemoteManagement

DisableRemoteAppleEvents
