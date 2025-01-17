#!/bin/zsh
#set -x

# Define variables
appname="CIS-L1-SystemSettings-UsersandGroups"
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

# Disables Guest Access to Shared Folders
DisableGuestAccessToSharedFolders() {
/usr/sbin/sysadminctl -smbGuestAccess off
echo "$(date) | Guest Access to Shared Folders is now disabled or already disabled. Closing script..."
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
DisableGuestAccessToSharedFolders
