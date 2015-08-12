#!/bin/bash

# audit command script
# V0.1 initial version
# V0.2 hardcode output directory as /tmp/
# V0.3 added header to report with host name and directory

# This script is designed to audit Oracle Weblogic 10g and 11g Forms files for SOX compliance
# The steps are :
#       1- report on world writeable files in /opt/bbyforms/appname (BEFORE)
#       2- remove world writeable permissions
#       3- report on world writeable files in /opt/bbyforms/appname (AFTER)
#       4- send report via email

# PARAMETERS
if [ $# -lt 2 ]; then
    echo "usage: $(basename $0) email_address audit_directory_1 [audit_directory_2 ... audit_directory_N]"
    exit 1
fi

# VARIABLES
# Space separated list of directories
email_recipient="$1"
email_subject="WW Files Audit"
email_body="Audit file(s) attached"
output_dir=/tmp/
attachment_file_name=$output_dir$(date '+%Y%m%d')_soxwwf_$(hostname).zip
# Just in case last run did not finish well
rm -f "$attachment_file_name"

# skip first parameter
shift
# loop through the rest of parameters
for audit_dir
do
	output_file_name=$output_dir$(date '+%Y%m%d')_soxwwf$(basename $audit_dir)_$(hostname).txt
	echo "Starting at $(date '+%Y-%m-%d %H:%M') on $(hostname)$audit_dir">$output_file_name
	# PART 1
	echo "Checking for world writeable files">>$output_file_name
	output_file_size=$(wc -c < $output_file_name)
	find "$audit_dir" -perm -o+w>>$output_file_name
	if [ $(wc -c < $output_file_name) == $output_file_size ]; then
		echo "No world writeable files found">>$output_file_name
	else
		# PART 2
		echo "Removing world writeable permissions">>$output_file_name
		chmod -R o-w "$audit_dir"
		# PART 3
		echo "Checking for world writeable files again">>$output_file_name
		output_file_size=$(wc -c < $output_file_name)
		find "$audit_dir" -perm -o+w>>$output_file_name
		if [ $(wc -c < $output_file_name) == $output_file_size ]; then
			echo "No world writeable files found">>$output_file_name
		fi
	fi
	# Move the output file to zip
	zip -um $attachment_file_name $output_file_name
done
# PART 4
# Send files via email
if hash uuencode &>/dev/null; then
	# Solaris 10
	(echo "$email_body"; uuencode $attachment_file_name $attachment_file_name) | mailx -s "$email_subject" $email_recipient
else
	# Linux
	echo "$email_body" | mailx -s "$email_subject" -a $attachment_file_name $email_recipient
fi

#Clean up
rm -f "$attachment_file_name"
