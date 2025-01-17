#!/bin/bash
#set -x

###########################################
##
## Script to install and setup AutoBrew
##
###########################################

# Define variables
currentRelease=$(curl --silent "https://api.github.com/repos/Homebrew/brew/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
swiftweburl="https://github.com/swiftDialog/swiftDialog/releases/download/v2.4.2/dialog-2.4.2-4755.pkg"
appname="AutoBrew"          # The name of our App deployment script
brewweburl="https://github.com/Homebrew/brew/releases/download/$currentRelease/Homebrew-$currentRelease.pkg"
logandmetadir="/Library/Logs/Microsoft/Intune/Scripts/$appname" # The location of our logs
tempdir=$(mktemp -d)
log="$logandmetadir/$appname.log" # The location of the script log file

# Functions
## function to delay script if the specified process is running
waitForProcess() {

    ##  Function to pause while a specified process is running
    ##
    ##  Functions used
    ##
    ##      None
    ##
    ##  Variables used
    ##
    ##      $1 = name of process to check for
    ##      $2 = length of delay (if missing, function to generate random delay between 10 and 60s)
    ##      $3 = true/false if = "true" terminate process, if "false" wait for it to close

    processName=$1
    fixedDelay=$2
    terminate=$3

    echo "$(date) | Waiting for other [$processName] processes to end"
    while ps aux | grep "$processName" | grep -v grep &>/dev/null; do

        if [[ $terminate == "true" ]]; then
            echo "$(date) | + [$appname] running, terminating [$processpath]..."
            pkill -f "$processName"
            return
        fi

        # If we've been passed a delay we should use it, otherwise we'll create a random delay each run
        if [[ ! $fixedDelay ]]; then
            delay=$(($RANDOM % 50 + 10))
        else
            delay=$fixedDelay
        fi

        echo "$(date) |  + Another instance of $processName is running, waiting [$delay] seconds"
        sleep $delay
    done

    echo "$(date) | No instances of [$processName] found, safe to proceed"

}

## Install App using Brew Function
function installBrewApp() {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and installs the app using Homebrew
    ##
    ##  Functions
    ##
    ##  Variables
    ##
    ##
    ##
    ###############################################################
    ###############################################################

    cd /opt
    if [[ $(uname -m) == 'arm64' ]]; then
        # Apple Silicon
        brewPath="/opt/homebrew/bin/brew"
    else
        # Intel
        brewPath="/usr/local/Homebrew/bin/brew"
    fi

    echo "$(date) | Installing ${1} using Homebrew"
    if $brewPath list $1 &>/dev/null; then
        echo "$(date) | Application ${1} is already installed"
        $brewPath update
        $brewPath upgrade $1
    else
        $brewPath install $1
        echo "$(date) | Application ${1} is installed"
    fi

}

## Install App using Brew Function
function installBrewTap() {

    #################################################################################################################
    #################################################################################################################
    ##
    ##  This function takes the following global variables and installs the tap using Homebrew
    ##
    ##  Functions
    ##
    ##  Variables
    ##
    ##
    ##
    ###############################################################
    ###############################################################

    cd /opt
    echo "$(date) | Installing ${1} using Homebrew"
    if [[ $(uname -m) == 'arm64' ]]; then
        # Apple Silicon
        brewPath="/opt/homebrew/bin/brew"
    else
        # Intel
        brewPath="/usr/local/Homebrew/bin/brew"
    fi

    brewtaps=$($brewPath tap)
    if [[ $brewtaps == *"$1"* ]]; then
        echo "$(date) | Brew Tap ${1} already installed"
    else
        $brewPath tap $1
        echo "$(date) | Brew Tap ${1} installed"
    fi

}

## Function to start logging
function startLog() {

    ###################################################
    ###################################################
    ##
    ##  start logging - Output to log file and STDOUT
    ##
    ####################
    ####################

    if [[ ! -d "$logandmetadir" ]]; then
        ## Creating Metadirectory
        echo "$(date) | Creating [$logandmetadir] to store logs"
        mkdir -p "$logandmetadir"
    fi

    exec &> >(tee -a "$log")

}

## Function to delay until the user has finished setup assistant.
waitForDesktop() {
    until ps aux | grep /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | grep -v grep &>/dev/null; do
        delay=$(($RANDOM % 50 + 10))
        echo "$(date) |  + Dock not running, waiting [$delay] seconds"
        sleep $delay
    done
    echo "$(date) | Dock is here, lets carry on"
}

# Begin Script Body
## Initiate logging
startLog

echo ""
echo "##############################################################"
echo "# $(date) | Logging install of [$appname] to [$log]"
echo "############################################################"
echo ""

## Wait for Desktop
waitForDesktop

## Swift Dialog install
## Note, Rosetta detection code from https://derflounder.wordpress.com/2020/11/17/installing-rosetta-2-on-apple-silicon-macs/
OLDIFS=$IFS
IFS='.' read osvers_major osvers_minor osvers_dot_version <<<"$(/usr/bin/sw_vers -productVersion)"
IFS=$OLDIFS

if [[ ${osvers_major} -ge 11 ]]; then

    # Check to see if the Mac needs Rosetta installed by testing the processor
    processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")

    if [[ -n "$processor" ]]; then
        echo "$(date) | $processor processor installed. No need to install Rosetta."
    else
        # Check for Rosetta "oahd" process. If not found,
        # perform a non-interactive install of Rosetta.
        if /usr/bin/pgrep oahd >/dev/null 2>&1; then
            echo "$(date) | Rosetta is already installed and running. Nothing to do."
        else
            /usr/sbin/softwareupdate --install-rosetta --agree-to-license
        fi
    fi
else
    echo "$(date) | Mac is running macOS $osvers_major.$osvers_minor.$osvers_dot_version."
    echo "$(date) | No need to install Rosetta on this version of macOS."
fi

#Install Homebrew

echo "$(date) | Starting Homebrew Installation"
cd /opt
echo "$(date) | Checking for Homebrew"
if [[ $(uname -m) == 'arm64' ]]; then
    # Apple Silicon
    brewPath="/opt/homebrew/bin/brew"
else
    # Intel
    brewPath="/usr/local/Homebrew/bin/brew"
fi

$brewPath --version &>/dev/null
if [[ $? != 0 ]]; then
    echo "$(date) | Downloading Homebrew from [$brewweburl]"
    cd "$tempdir"
    waitForProcess "curl -f"
    curl -f -s --connect-timeout 30 --retry 5 --retry-delay 60 --compressed -L -J -o "$tempdir/homebrew.pkg" "$brewweburl"
    # Installing Homebrew
    echo "$(date) | Installing Homebrew"
    installer -pkg "$tempdir/homebrew.pkg" -target /
    # Checking if the app was installed successfully
    if [ "$?" = "0" ]; then

        echo "$(date) | HomeBrew succesfully installed"

    else

        echo "$(date) | Failed to install Brew"
        exit 1
    fi
else

    echo "$(date) | HomeBrew already installed"
fi

## Install SwiftDialog
echo "$(date) | Starting SwiftDialog Installation"
cd /opt
echo "$(date) | Checking for SwiftDialog"
dialog --version &>/dev/null
if [[ $? != 0 ]]; then
    echo "$(date) | Downloading SwiftDialog from [$swiftweburl]"
    cd "$tempdir"
    waitForProcess "curl -f"
    curl -f -s --connect-timeout 30 --retry 5 --retry-delay 60 --compressed -L -J -o "$tempdir/swiftdialog.pkg" "$swiftweburl"
    # Installing SwiftDialog
    echo "$(date) | Installing SwiftDialog"
    installer -pkg "$tempdir/swiftdialog.pkg" -target /
    # Checking if the app was installed successfully
    if [ "$?" = "0" ]; then
        echo "$(date) | SwiftDialog succesfully installed"

    else
        echo "$(date) | Failed to install SwiftDialog"
        exit 1
    fi
else

    echo "$(date) | SwiftDiaglog already installed"
fi

## Install X-Code Command line tools
echo "$(date) | Starting Xcode Command Line Tools Installation"
cd /opt
echo "$(date) | Checking for Xcode Command Line Tools"
xcode-select -p &>/dev/null
if [ $? -ne 0 ]; then
    echo "$(date) | Installing Xcode Command Line Tools"
    # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    PROD=$(softwareupdate -l | grep "\*.*Command Line" | tail -n 1 | sed 's/^[^C]* //')
    softwareupdate -i "$PROD" --verbose
else
    echo "$(date) | Xcode Command Line Tools already installed"
fi

## Install mas-cli

installBrewApp "mas"

## Install Brew Cask Upgrade

installBrewTap "buo/cask-upgrade"
