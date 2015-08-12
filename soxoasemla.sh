#!/bin/bash

# SOX audit script for OAS EM logins
# V0.1 initial version
# V0.2 added text for empty log files

# This script is designed to audit Oracle Weblogic 10g security log files looking for authenticated users
# The steps are :
#       1- find the log files updated on the day before the script is run
#       2- parse the log files looking for user timestamps, user names, and roles
#       3- add in-range portion of the logs to a temp log
#       4- zip and send report via email

# PARAMETERS
if [ $# -lt 1 ]; then
    echo "usage: $(basename $0) email_address"
    exit 1
fi

# VARIABLES
# String representation of yesterday's date
yesterday=$(perl -MPOSIX=strftime -e 'print strftime("%Y-%m-%d", localtime(time-24*60*60))')
# String representation of the current log event timestamp in the loop
timestamp=""
# Flag if the current log event in the loop is in range
in_range=0
# OAS EM log file directory
log_dir=/opt/app/oracle/product/10.1.3.0/j2ee/home/log/home_default_group_1/oc4j/
email_recipient="$1"
email_subject="OAS EM Login Audit"
email_body="Audit file(s) attached"
output_dir=/tmp/
output_report_name=$output_dir$(date '+%Y%m%d')_soxoasemla_$(hostname).txt
echo "Starting at $(date '+%Y-%m-%d %H:%M') on $(hostname)" > "$output_report_name"
echo "Parsing OAS EM logs for logins on $yesterday" >> "$output_report_name"
output_report_size=$(wc -c < "$output_report_name")
output_log_name=$output_dir$(date '+%Y%m%d')_soxoasemla_$(hostname).xml
rm -f "$output_log_name"
attachment_file_name=$output_dir$(date '+%Y%m%d')_soxoasemla_$(hostname).zip
rm -f "$attachment_file_name"

# Find log files modified with the last two days and list them by modification date, one per line
# we don't have too many files and file names don't have spaces - this simplified bash will work
# find -type f - only files, not directories
# find -mtime -2 - modification date 48 hours ago or less
# ls -1 - one file name per line
# ls -t - in descending order by time modified
# ls -r - reverse sorting order
# ls /dev/null - in case the previous command finds no files, we don't want to default to "."
# IFS='' - prevents trimming of the leading/trailing spaces
# read -r - raw read
find "$log_dir" -type f -mtime -2 | xargs ls -1tr /dev/null | xargs cat | while IFS='' read -r line; do
	if [[ ${line:0:22} == "    <TSTZ_ORIGINATING>" ]]; then
		# Get a timestamp of the current log event
		timestamp=${line:22:29}
		# If the timestamp falls within previous midnight-to-midnight (yesterday), then the event is in range
		if [[ ${timestamp:0:10} == $yesterday ]]; then
			in_range=1
		else
			in_range=0
		fi
	elif [[ $in_range == 1 ]]; then
		case "$line" in
			*"[AbstractLoginModule] added Principal RealmUser:"*)
				echo $timestamp
				# Break the line into words and print the sixth word - user name
				echo $line | awk '{print "\t"$6}'
			;;
			*"[AbstractLoginModule] added Principal RealmRole:"*)
				# Break the line into words and print the sixth word - role name
				echo $line | awk '{print "\t\t"$6}'
			;;
		esac
	fi
	if [[ $in_range == 1 ]]; then
		printf "%s\n" "$line" >> "$output_log_name"
	fi
done >> "$output_report_name"

if [ $(wc -c < "$output_report_name") == $output_report_size ]; then
	echo "No logins found" >> "$output_report_name"
fi

# PART 4
# Move the output files to zip, Update the archive, Junk the path
zip -umj $attachment_file_name $output_report_name $output_log_name

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
