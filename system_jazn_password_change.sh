#!/bin/bash

# Password change script
# V01 initial version
# V02 built-in XSLT
# V03 user name is a parameter
# V04 password is read interactively instead of being a parameter (to avoid being saved in history)

# PARAMETERS
if [ $# -ne 1 ]; then
	echo "usage: $(basename $0) userName"
	exit 1
fi

# VARIABLES
# Config file name
file_name="system-jazn-data.xml"
# Config files
config_files=$ORACLE_HOME/j2ee/*/config/$file_name
# Temp file name
tmp_file_name=""
# Number of modifications
diff_res=0
# Timestamp to add to backup files
timestamp=$(date '+%Y%m%d%H%M%S')

read -p "What's the new password for $1? " newPassword

# Prepare all the modified config files
echo "Making copies of $file_name files and modifying them."
for f in $config_files; do
	tmp_file_name="$f".tmp
# $newPassword is an XSLT parameter, to take advantage of XML encoding done by xsltproc
# $1 - userName is substituted in the here doc because our version of xsltproc only supports XSL 1.0, and it doesn't allow parameters in "match"
	xsltproc -o "$tmp_file_name" --stringparam newPassword '!'"$newPassword" - "$f"<<EOF
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<!-- DTD for system-jazn-data.xml, there is no way to copy it, so we have to declare it here -->
	<xsl:output version="1.0" encoding="UTF-8" standalone="yes"/>
<!-- Standard design pattern to copy all XML content - identity transform -->
	<xsl:template match="@*|node()">
		<xsl:copy>
			<xsl:apply-templates select="@*|node()"/>
		</xsl:copy>
	</xsl:template>
<!-- Replace the old user password with the newPassword parameter -->
	<xsl:template match="jazn-data/jazn-realm/realm/users/user[name/text() = '$1']/credentials/text()">
		<xsl:value-of select="\$newPassword"/>
	</xsl:template>
</xsl:stylesheet>
EOF
# Does the modified file pass the sanity checks?
# The number of modifications should always be 1 - the password line for the user
	diff_res=$(diff -c "$f" "$tmp_file_name"|grep -c "\*\*\*\*\*\*\*\*\*\*\*\*")
	if [ "$diff_res" -ne 1 ]; then
		diff "$f" "$tmp_file_name"
		read -p "The number of modifications in $tmp_file_name is $diff_res (expected 1). Press 'y' to proceed, 'n' to abort: " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			echo "Aborting. No live $file_name files have been changed."
			exit 1
		fi
	fi
# The resulting file should be a valid XML file
	xmllint "$tmp_file_name" --noout
	if [ "$?" -ne 0 ]; then
		head -10 "$tmp_file_name"
		echo "$tmp_file_name is not a valid XML file. Aborting. No live $file_name files have been changed."
		exit 1
	fi
done
echo "Success. Copies of $file_name files are ready."

# Confirm that we actually want to modify the live config files
read -p "Press 'y' to replace live $file_name files with the modified copies, 'n' to abort: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo "Aborting. No live $file_name files have been changed."
	exit 1
fi

# Making backup copies
for f in $config_files; do
	cp -p "$f" "$f".bkp."$timestamp"
	if [ "$?" -ne 0 ]; then
		echo "Couldn't make a backup copy of $f. Aborting. No live $file_name files have been changed."
		exit 1
	fi
done

# Replace the live config files with the modified versions
for f in $config_files; do
	tmp_file_name="$f".tmp
	mv "$tmp_file_name" "$f"
	if [ "$?" -ne 0 ]; then
		echo "There was a problem replacing $f with $tmp_file_name."
	else
		echo "$f has been successfully modified."
	fi
done
