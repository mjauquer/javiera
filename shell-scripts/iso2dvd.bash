#! /bin/bash

# iso2dvd.bash (See description below).
# Copyright (C) 2012  Marcelo Javier Auquer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
#        USAGE: See function usage below.
#
#  DESCRIPTION: Burn a dvd from the SOURCE image file. Update the backup
#               database with the pertinent data.
#
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               javiera.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/.myconf/javiera.cnf || exit 1
source ~/projects/javiera/shell-scripts/functions/javiera-core.bash ||
	exit 1

usage () {

#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.

	cat <<- EOF
	Usage: iso2dvd SOURCE

	Burn a dvd from the SOURCE image file. Update the backup
	database with the pertinent data.
	EOF
}

error_exit () {

#       USAGE: error_exit [MESSAGE]
#
# DESCRIPTION: Function for exit due to fatal program error.
#
#   PARAMETER: MESSAGE An optional description of the error.

	echo "${progname}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

# If no argument was passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

# Variables declaration.

declare progname # This script's name.
declare input    # The pathname of the image file to be burned.
declare version  # The version of the cdrecord command.
declare options  # The options to be passed to the cdrecord command.
declare user     # A mysql user name.
declare pass     # A mysql password.
declare db       # A mysql database.

progname=$(basename $0)

# Checking for a well-formatted command line.
if [ $# -ne 1 ]
then
	usage
elif [[ $1 =~ .*/$ ]]
then
	"Argument must be a regular filename."
fi

#-----------------------------------------------------------------------
# Ask to the user for the dvd's type.
#-----------------------------------------------------------------------

declare -a dvd_types
declare dvd_type_id

# Get dvd types from the database.
dvd_types=( $(mysql --skip-reconnect -u$user -p$pass -D$db \
	--skip-column-names -e "

	SELECT id, type_descriptor
		FROM dvd_type
		WHERE type_descriptor RLIKE 'dvd.*'
	;
") )
[[ $? -ne 0 ]] && return 1

for (( i=0; i<${#dvd_types[@]}; i=$((i+2)) ))
do
	menu+="${dvd_types[i]}) ${dvd_types[i+1]}
"
done
unset -v i

# Ask the user for the dvd type being used.
echo "Select the DVD type that is being used:"
echo "$menu"

while [[ ! $dvd_type_id ]] ||
	[[ $dvd_type_id -gt ${#dvd_types[@]} ]] ||
	[[ ! $dvd_type_id =~ ^[0-9]+$ ]]
do
	read -r dvd_type_id
done
unset -v dvd_types

#-----------------------------------------------------------------------
# Burn the DVD.
#-----------------------------------------------------------------------

options="-v speed=4 dev=ATAPI:0,0,0" 

version="$(cdrecord -version)"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling cdrecord."
fi

input=$(readlink -f $1)
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling readlink."
fi

if ! sudo cdrecord $options $input
then
	error_exit "$LINENO: Error after calling cdrecord."
fi

#-----------------------------------------------------------------------
# Update the backup database.
#-----------------------------------------------------------------------

if ! sudo mount -t iso9660 /dev/sr0 /mnt/cdrom
then
	error_exit "$LINENO: Error after trying to mount media."
fi

if ! process_fstab
then
	error_exit "$LINENO: Error after calling process_fstab()."
fi

while read line
do
	if [[ $line =~ UUID=.* ]]
	then
		fs_uuid=${line#UUID=}
	fi
done < /mnt/cdrom/.javiera/info.txt

dvd_type_id=\'$dvd_type_id\'
fs_uuid=\'$fs_uuid\'

declare dvd_id
dvd_id=$(mysql --skip-reconnect -u$user -p$pass -D$db \
	--skip-column-names -e "

	CALL insert_and_get_dvd ($dvd_type_id, @dvd_id);
	SELECT device.id INTO @data_storage_device_id
		FROM data_storage_device AS device
		INNER JOIN digital_media AS media
			ON device.id = media.data_storage_device_id
		INNER JOIN dvd
			ON media.id = dvd.digital_media_id
		WHERE dvd.id = @dvd_id
	;
	SELECT id INTO @file_system_id
		FROM file_system
		WHERE uuid = $fs_uuid
	;
	CALL link_file_system_to_data_storage_device (
		@file_system_id,
		@data_storage_device_id
	);
	SELECT @dvd_id;
")
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mysql."
fi
unset -v dvd_type_id
unset -v fs_uuid

# Insert details of the software and options used to create the dvd.

version=\'$version\'
options=\'$options\'

session_id=$(mysql --skip-reconnect -u$user -p$pass -D$db \
	--skip-column-names -e "

	CALL insert_and_get_software ('cdrecord', $version, @software_id);
	CALL insert_and_get_software_session (
		@software_id,
		$options,
		@software_session_id
	);
	SELECT @software_session_id;

")
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mysql."
fi
unset -v options
unset -v version

session_id=$session_id
session_id=\'$session_id\'
mysql --skip-reconnect -u$user -p$pass -D$db \
	--skip-column-names -e "

	CALL link_dvd_to_software_session ($dvd_id, $session_id);
"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling mysql."
fi
unset -v session_id

# Print id number of the recently burned dvd.

echo "Burned dvd number $dvd_id."
unset -v dvd_id

sudo umount /mnt/cdrom
