#!/bin/zsh
#set -x

# Define variables
appname="CIS-L1-SystemSettings-PrivacyandSecurity"
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

# Set to ensure an Administrator account cannot login to another user's active and locked session
AdministratorAccountCannotLoginToAnotherUsersActiveAndLockedSession() {
    /usr/bin/security authorizationdb write system.login.screensaver use-login-window-ui
    echo "$(date) | Administrator account cannot login to another user's active and locked session is now set or is already set. Closing script..."
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
AdministratorAccountCannotLoginToAnotherUsersActiveAndLockedSession
