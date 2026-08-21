#!/bin/bash
# =============================================================
# Defender Antivirus Compliance Script for Intune
# Checks: Installation, health, running, real-time protection, and Definition status
# Author : Nick Benton
# Logs to: /Library/Logs/Microsoft/IntuneScripts/Compliance/DefenderAntivirus.log
# Output : single-line JSON to stdout | Exit 0
# =============================================================

# User Defined variables
scriptName="DefenderAntivirus"
logDir="/Library/Logs/Microsoft/IntuneScripts/Compliance"
logFile="$logDir/$scriptName.log"
maxLogSize=1048576 # 1 MB rotation threshold

# logging
if [[ ! -d "$logDir" ]]; then
	mkdir -p "$logDir"
fi

if [[ -f "$logFile" ]]; then
	logSize=$(stat -f%z "$logFile" 2>/dev/null || echo 0)
	[[ "$logSize" -gt "$maxLogSize" ]] && mv "$logFile" "${logFile}.1"
fi
touch "$logFile" 2>/dev/null
chmod 644 "$logFile" 2>/dev/null

# functions
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >>"$logFile"; }

# Log a check: ID | raw value read | evaluated result
logcheck() { log "$1 | raw='$2' | result=$3"; }

consoleUser=$(stat -f%Su /dev/console)
log "=============================================================="
log "RUN START | user=$(whoami) | consoleUser=$consoleUser | tty=$([[ -t 0 ]] && echo yes || echo no) | PATH=$PATH"
log "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
log "=============================================================="

# Compliance checks
log "Checking Microsoft Defender Antivirus"
MDATP="/usr/local/bin/mdatp"
if [[ -x "$MDATP" ]]; then
	log "Microsoft Defender Antivirus is installed"
	defenderInstalled="true"

	# Check if Defender service is running
	pgrep -x "wdavdaemon" >/dev/null 2>&1 && defenderRunning="true" || defenderRunning="false"

	# Check health status
	healthy=$("$MDATP" health --field healthy 2>/dev/null | tr -d '"')
	[[ "$healthy" == "true" ]] && defenderHealthy="true" || defenderHealthy="false"
	logcheck "Defender-Healthy (mdatp health healthy)" "$healthy" "$defenderHealthy"

	# Check real-time protection status
	realTimeProtection=$("$MDATP" health --field real_time_protection_enabled 2>/dev/null | tr -d '"')
	[[ "$realTimeProtection" == true* ]] && defenderRealTimeProtection="true" || defenderRealTimeProtection="false"
	logcheck "Defender-RealtimeProtectionEnabled (mdatp health real_time_protection_enabled)" "$realTimeProtection" "$defenderRealTimeProtection"

	# Get definitions status - check if they're up to date
	definitionsCurrent=$("$MDATP" health --field definitions_status 2>/dev/null | tr -d '"')
	[[ "$definitionsCurrent" == "up_to_date" ]] && defenderDefinitionsCurrent="true" || defenderDefinitionsCurrent="false"
	logcheck "Defender-DefinitionsUpToDate (mdatp health definitions_status)" "$definitionsCurrent" "$defenderDefinitionsCurrent"

else
	log "Microsoft Defender Antivirus is not installed"
	defenderInstalled="false"
	defenderRunning="false"
	defenderHealthy="false"
	defenderRealTimeProtection="false"
	defenderDefinitionsCurrent="false"
fi

json="{\"Defender-Installed\": $defenderInstalled, \"Defender-Running\": $defenderRunning, \"Defender-Healthy\": $defenderHealthy, \"Defender-RealtimeProtectionEnabled\": $defenderRealTimeProtection, \"Defender-DefinitionsUpToDate\": $defenderDefinitionsCurrent}"
log "SUBMITTED JSON: $json"
fails=$(echo "$json" | grep -o "false" | wc -l | tr -d ' ')
log "=============================================================="
log "RUN END | non-compliant settings: $fails"
log "=============================================================="

echo "$json"
exit 0
