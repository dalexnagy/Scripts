#!/bin/bash

# Script to run backup and send results via Email
# Set default subject line
# Return value from Perl script is '0' if successful ($OK in Perl)
#

thisHost=$(hostname)

# Daily backup of home directory and DATA to Server (DataVolume)

/home/dave/Perl/Backups/Backup2Server.pl > /tmp/Backup2ServerMessages.txt
endTime=$(date +%T)

if [ $? -ne 0 ]; then
	SUBJ="[FAILED] '$thisHost' Backup to Server FAILED! See messages below."
	notify-send "[FAILED] '$thisHost' Backup to Server FAILED @ $endTime"
else
	SUBJ="*OK* '$thisHost' Backup to Server was SUCCESSFUL. See messages below."
	notify-send "*OK* '$thisHost' Backup to Server was SUCCESSFUL @ $endTime"
fi

# Email to...
EMAIL="danagy@tampabay.rr.com"
mail -s "$SUBJ" "$EMAIL" < /tmp/Backup2ServerMessages.txt

exit 0
