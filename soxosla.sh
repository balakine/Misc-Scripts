#!/bin/bash

# machine log audit
# V0.1 initial version

# This script is designed to audit wtmp log file by issuing 'last' command
# The steps are :
#	1- capture output of 'last' command for all the log files
#	2- send report via email

# PARAMETERS
if [ $# -lt 1 ]; then
	echo "usage: $(basename $0) email_address [days:1]"
	exit 1
fi

# VARIABLES
email_recipient="$1"
email_subject="OS Login Audit"
email_body="Audit file attached"
default_period=1
period="${2:-$default_period}"
output_dir=/tmp/
attachment_file_name=$output_dir$(date '+%Y%m%d')_soxosla_$(hostname).zip
# Just in case last run did not finish well
rm -f "$attachment_file_name"

output_file_name=$output_dir$(date '+%Y%m%d')_soxosla_$(hostname).txt
echo "Starting at $(date '+%Y-%m-%d %H:%M') on $(hostname)">$output_file_name
# PART 1
if [ -e /var/adm/wtmpx ]; then
	# Solaris 10
	for i in `ls -t /var/adm/wtmpx*`; do last -a -f "$i"; done
elif [ -e /var/log/wtmp ]; then
	# Linux
	for i in `ls -t /var/log/wtmp*`; do last -a -f "$i"; done
else
	# no wtmp log?
	last -a
fi >>$output_file_name

# Move the output file to zip, Update the archive, Junk the path
zip -umj $attachment_file_name $output_file_name
# PART 2
# Send files via email
if hash uuencode &>/dev/null; then
	# Solaris 10
	(echo "$email_body"; uuencode $attachment_file_name $(basename $attachment_file_name)) | mailx -s "$email_subject" $email_recipient
else
	# Linux
	echo "$email_body" | mailx -s "$email_subject" -a $attachment_file_name $email_recipient
fi

#Clean up
rm -f "$attachment_file_name"
