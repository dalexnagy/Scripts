#!/bin/bash

# Script to run backup to USB drive and send results via Email
# Set default subject line
# Return value from Perl script is '0' if successful ($OK in Perl)
#

thisHost=$(hostname)

# Daily backup of home directory and SHARED to USB drive

/home/dave/Perl/Backups/Backup2USBDrive.pl > /tmp/Backup2USBDriveMessages.txt
endTime=$(date +%T)

if [ $? -ne 0 ]; then
	SUBJ="[FAILED] '$thisHost' Backup to USB Drive FAILED! See messages below."
	notify-send "[FAILED] '$thisHost' Backup to USB Drive FAILED @ $endTime"
else
	SUBJ="*OK* '$thisHost' Backup to USB Drive was SUCCESSFUL. See messages below."
	notify-send "*OK* '$thisHost' Backup to USB Drive was SUCCESSFUL @ $endTime"
fi

# Email to...
EMAIL="danagy@tampabay.rr.com"
mail -s "$SUBJ" "$EMAIL" < /tmp/Backup2USBDriveMessages.txt

exit 0
