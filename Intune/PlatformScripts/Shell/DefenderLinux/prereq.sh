#!/bin/bash

yes | sudo apt-get install curl

yes | sudo apt-get install libplist-utils

#Adjust the version, select the appropriate update channel, and specify the distribution settings to align with your specific environment requirements
osVersion=$(lsb_release -rs)

curl -o microsoft.list "https://packages.microsoft.com/config/ubuntu/$osVersion/prod.list"

sudo mv ./microsoft.list /etc/apt/sources.list.d/microsoft-prod.list

yes | sudo apt-get install gpg

curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg >/dev/null

yes | sudo apt-get install apt-transport-https

sudo apt-get update

yes | sudo apt-get install mdatp
