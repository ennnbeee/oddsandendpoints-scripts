#!/bin/bash
#set -x

############################################################################################
##
## Script to download Teams Backgrounds
##
###########################################

# Define variables
# Add new background URLs to the array
backgroundurls=("https://raw.githubusercontent.com/ennnbeee/mem-scripts/main/Intune/Scripts/Shell/TeamsBackgrounds/Msft_Nostalgia_Landscape.jpg"
  "https://raw.githubusercontent.com/ennnbeee/mem-scripts/main/Intune/Scripts/Shell/TeamsBackgrounds/SupportUkraine_Heart_TeamsBackground.jpg"
  "https://raw.githubusercontent.com/ennnbeee/mem-scripts/main/Intune/Scripts/Shell/TeamsBackgrounds/covermichael.jpg")

scriptname="SetTeamsBackground"
teamsapp="/Applications/Microsoft Teams.app"
logandmetadir="$HOME/Library/Logs/Microsoft/Intune/Scripts/$scriptname"
log="$logandmetadir/$scriptname.log"
teamsUpload="$HOME/Library/Application Support/Microsoft/Teams/Backgrounds/Uploads"

## Check if the log directory has been created
if [ -d $logandmetadir ]; then
  ## Already created
  echo "# $(date) | Log directory already exists - $logandmetadir"
else
  ## Creating Metadirectory
  echo "# $(date) | creating log directory - $logandmetadir"
  mkdir -p "$logandmetadir"
fi

# start logging
exec 1>>"$log" 2>&1

echo ""
echo "##############################################################"
echo "# $(date) | Starting download of Teams Backgrounds"
echo "############################################################"
echo ""

##
## Checking if Teams is Installed
##
while [[ $ready -ne 1 ]]; do
  missingappcount=0
  if [[ -e "$teamsapp" ]]; then
    echo "$(date) |  $teamsapp is installed"
  else
    let missingappcount=$missingappcount+1
  fi
  echo "$(date) |  [$missingappcount] application missing"

  if [[ $missingappcount -eq 0 ]]; then
    ready=1
    echo "$(date) |  Teams App found, lets download the backgrounds"
  else
    echo "$(date) |  Waiting for 10 seconds"
    sleep 10
  fi
done

##
## Checking if Teams Backgrounds Upload directory exists and create it if it's missing
##
if [[ -d ${teamsUpload} ]]; then
  echo "$(date) | Teams Background Upload dir [$teamsUpload] already exists"
else
  echo "$(date) | Creating [$teamsUpload]"
  mkdir -p "$teamsUpload"
fi

##
## Attempt to download the files. No point checking if it already exists since we want to overwrite it anyway
##
i=0
for backgroundurl in "${backgroundurls[@]}"; do
  ((i = i + 1))
  backgroundfile="TeamsBackground$i.png"
  echo "$(date) | Downloading Background from [$backgroundurl] to [$teamsUpload/$backgroundfile]"
  curl -L -o "$teamsUpload/$backgroundfile" $backgroundurl
  if [ "$?" = "0" ]; then
    echo "$(date) | Teams Background [$backgroundurl] downloaded to [$teamsUpload/$backgroundfile]"
  else
    echo "$(date) | Failed to download Teams Background image from [$backgroundurl]"
  fi
done
