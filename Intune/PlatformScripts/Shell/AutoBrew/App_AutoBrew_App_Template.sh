#!/bin/bash
#set -x

###########################################
##
## Script to install an App using AutoBrew
##
###########################################

# Define variables
brewApp="skype" # Brew App to be installed
currentRelease=$(curl --silent "https://api.github.com/repos/Homebrew/brew/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
brewweburl="https://github.com/Homebrew/brew/releases/download/$currentRelease/Homebrew-$currentRelease.pkg"
logandmetadir="/Library/Logs/Microsoft/Intune/Scripts/AutoBrew" # The location of our logs
tempdir=$(mktemp -d)
log="$logandmetadir/$brewApp.log" # The location of the script log file

# Functions
## function to delay script if the specified process is running
waitForProcess() {

    #################################################################################################################
    #################################################################################################################
    ##
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
    ##
    ###############################################################
    ###############################################################

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

## Function to delay until the user has finished setup assistant.
waitForDesktop() {
    until ps aux | grep /System/Library/CoreServices/Dock.app/Contents/MacOS/Dock | grep -v grep &>/dev/null; do
        delay=$(($RANDOM % 50 + 10))
        echo "$(date) |  + Dock not running, waiting [$delay] seconds"
        sleep $delay
    done
    echo "$(date) | Dock is here, lets carry on"
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

# Begin Script Body
## Initiate logging
startLog

echo ""
echo "##############################################################"
echo "# $(date) | Logging install of [$brewApp] to [$log]"
echo "############################################################"
echo ""

## Wait for Desktop
waitForDesktop

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

## Install Brew App
installBrewApp $brewApp
