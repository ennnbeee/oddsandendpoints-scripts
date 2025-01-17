#!/bin/bash
#set -x

############################################################################################
##
## Script to download Teams Backgrounds
##
###########################################

# Define variables
# Add new background URLs to the array
backGroundUrls=("https://raw.githubusercontent.com/ennnbeee/ennnbeee.github.io/main/bgr.png"
  "https://raw.githubusercontent.com/ennnbeee/ennnbeee.github.io/main/img/feature-bg.png")

scriptName="SetNewTeamsBackgrounds"
logAndMetaDir="$HOME/Library/Logs/Microsoft/IntuneScripts/$scriptName" # Running under the user context
log="$logAndMetaDir/$scriptName.log"

##
## Check if the log directory has been created
##
if [ -d $logAndMetaDir ]; then
  ## Already created
  echo "# $(date) | Log directory already exists - $logAndMetaDir"
else
  ## Creating Metadirectory
  echo "# $(date) | Creating log directory - $logAndMetaDir"
  mkdir -p "$logAndMetaDir"
fi

# start logging
exec 1>>"$log" 2>&1

echo ""
echo "##############################################################"
echo "# $(date) | Starting download of Teams Backgrounds"
echo "############################################################"
echo ""

## Function to Check what version of Teams is installed and set the path for the backgrounds
function checkAndSetInstalledMSTeamsPath() {
  if [[ -e "/Applications/Microsoft Teams.app" ]]; then
    teamsApp="/Applications/Microsoft Teams.app"
    teamsUpload="$HOME/Library/Application Support/Microsoft/Teams/Backgrounds/Uploads"
  elif [[ -e "/Applications/Microsoft Teams classic.app" ]]; then
    teamsApp="/Applications/Microsoft Teams classic.app"
    teamsUpload="$HOME/Library/Application Support/Microsoft/Teams/Backgrounds/Uploads"
  elif [[ -e "/Applications/Microsoft Teams (work or school).app" ]]; then
    teamsApp="/Applications/Microsoft Teams (work or school).app"
    teamsUpload="$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds/Uploads"
  elif [[ -e "/Applications/Microsoft Teams (work preview).app" ]]; then
    teamsApp="/Applications/Microsoft Teams (work preview).app"
    teamsUpload="$HOME/Library/Containers/com.microsoft.teams2/Data/Library/Application Support/Microsoft/MSTeams/Backgrounds/Uploads"
  fi
}

##
## Checking if Teams is installed
##
echo "$(date) | Checking if Microsoft Teams is installed."
ready=0
while [[ $ready -ne 1 ]]; do
  teamsMissing=0
  checkAndSetInstalledMSTeamsPath
  if [[ -z "$teamsApp" ]]; then
    let teamsMissing=$teamsMissing+1
    echo "$(date) | Microsoft Teams application is missing."
  else
    echo "$(date) | Microsoft Teams application is installed."
  fi

  if [[ $teamsMissing -eq 0 ]]; then
    ready=1
    echo "$(date) | Microsoft Teams App $teamsApp found, lets download the backgrounds."
  else
    echo "$(date) | Waiting for 10 seconds before trying again."
    sleep 10
  fi
done

##
## Checking if Teams Backgrounds Upload directory exists and create it if it's missing
##
if [[ -d ${teamsUpload} ]]; then
  echo "$(date) | Microsoft Teams Background Upload directory [$teamsUpload] already exists"
else
  echo "$(date) | Creating directory [$teamsUpload]"
  mkdir -p "$teamsUpload"
fi

##
## Attempt to download the files. No point checking if it already exists since we want to overwrite it anyway
##

echo "$(date) | Creating Microsoft Teams backgrounds in $teamsUpload"
# The new Microsoft Teams app needs UUIDs and a Thumbnail
for backGroundUrl in "${backGroundUrls[@]}"; do
  uuid=$(uuidgen | tr "[:upper:]" "[:lower:]")
  backgroundFile=$uuid.png
  backgroundThumb=${uuid}_thumb.png

  echo "$(date) | Downloading Background from [$backGroundUrl] to [$teamsUpload/$backgroundFile]"
  curl -L -o "$teamsUpload/$backgroundFile" $backGroundUrl
  if [ "$?" = "0" ]; then
    echo "$(date) | Microsoft Teams Background [$backGroundUrl] downloaded to [$teamsUpload/$backgroundFile]"
  else
    echo "$(date) | Failed to download Teams Background image from [$backGroundUrl]"
  fi

  if [[ $teamsUpload = *Containers* ]]; then
    echo "$(date) | Downloading Thumbnail from [$backGroundUrl] to [$teamsUpload/$backgroundThumb]"
    curl -L -o "$teamsUpload/$backgroundThumb" $backGroundUrl
    if [ "$?" = "0" ]; then
      echo "$(date) | Microsoft Teams Thumbnail [$backGroundUrl] downloaded to [$teamsUpload/$backgroundThumb]"
    else
      echo "$(date) | Failed to download Teams Thumbnail image from [$backGroundUrl]"
    fi
  fi
done
