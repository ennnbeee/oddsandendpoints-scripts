#!/bin/zsh
#set -x

# Define variables
appname="CIS-L1-SystemSettings-Battery"
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

# First checking CPU architecture and then disables Power Nap if device is Intel Mac
DisablePowerNapForIntelMacs() {
    echo "$(date) | Detecting CPU architecture..."
    if [[ $(uname -m) == 'arm64' ]]; then
        # This is Apple Silicon. We don't need to run this script for these devices
        echo "$(date) | CPU architecture is Apple Silicon. We don't need to run this script for this CPU to disable Power Nap. Closing script..."
        exit 0
    else
        # Disables Power Nap for Intel Macs
        echo "$(date) | CPU architecture is Intel. Therefore, we need to make sure that Power Nap is disabled or already disabled. Applying needed changes..."
        /usr/bin/pmset -a powernap 0
        echo "$(date) | Power Nap is disabled or already disabled for your Intel Mac. Closing script..."
    fi
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
DisablePowerNapForIntelMacs
