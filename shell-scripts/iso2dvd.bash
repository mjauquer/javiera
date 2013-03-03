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
# REQUIREMENTS: cdrecord
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

declare progname # This script's name.

progname=$(basename $0)

# If no argument was passed, print usage message and exit.
[[ $# -eq 0 ]] && usage && exit

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

declare db           # A mysql database.
declare -a dvd_types
declare dvd_type_id
declare user         # A mysql user name.
declare pass         # A mysql password.

# Get dvd types from the database.
dvd_types=( $($mysql_path --skip-reconnect -u$user -p$pass -D$db \
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
echo "$menu"

while [[ ! $dvd_type_id ]] ||
	[[ $dvd_type_id -gt ${#dvd_types[@]} ]] ||
	[[ ! $dvd_type_id =~ ^[0-9]+$ ]]
do
	printf "Select the DVD type that is being used: "
	read -r dvd_type_id
	echo ""
done
unset -v dvd_types

#-----------------------------------------------------------------------
# Burn the DVD.
#-----------------------------------------------------------------------

declare options  # The options to be passed to the cdrecord command.
declare version  # The version of the cdrecord command.

options="-v -sao -eject speed=8 dev=$(cdrecord -scanbus 2> /dev/null | grep SE-208AB | cut -f 2)" 

version="$(cdrecord -version)"
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling cdrecord."
fi

declare input # The pathname of the image file to be burned.

input=$(readlink -f $1)
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after calling readlink."
fi

if ! sudo cdrecord $options $input
then
	error_exit "$LINENO: Error after calling cdrecord."
fi

unset -v input

while printf "Close the tray and press <c> to continue: "
do
	read answer 
	case $answer in
		c) break
		   ;;
		*) echo "Close the tray and press <c> to continue: "
		   continue
		   ;;
	esac
done

#-----------------------------------------------------------------------
# Update the backup database.
#-----------------------------------------------------------------------

# Mount the dvd device.

declare volume  # The mount point corresponding to the dvd device.
declare mounted # "true" is the dvd device is mounted.

volume="/mnt/dvd/1"

# Get the uuid related to the implanted file system.

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
done < $volume/.javiera/info.txt

# Update the database.

declare dvd_id

dvd_type_id=\'$dvd_type_id\'
fs_uuid=\'$fs_uuid\'
options=\'$options\'
version=\'$version\'

dvd_id=$($mysql_path --skip-reconnect -u$user -p$pass -D$db \
	--skip-column-names -e "

	START TRANSACTION;
	CALL insert_and_get_dvd ($dvd_type_id, @dvd_id);
	SELECT device.id INTO @data_storage_device_id
		FROM data_storage_device AS device
		INNER JOIN dvd
			ON device.id = dvd.data_storage_device_id
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

	CALL insert_and_get_software ('cdrecord', $version, @software_id);
	CALL insert_and_get_software_session (
		@software_id,
		$options,
		@software_session_id
	);

	CALL link_dvd_to_software_session (@dvd_id, @software_session_id);

	SELECT @dvd_id;
	COMMIT;
")
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after a call to mysql."
fi

javiera -r $volume
if [ $? -ne 0 ]
then
	error_exit "$LINENO: Error after a call to javiera.bash."
fi

unset -v dvd_type_id
unset -v fs_uuid
unset -v options
unset -v version
unset -v db
unset -v pass
unset -v user

# Print the id number of the recently burned dvd.

echo "Burned dvd number $dvd_id."

unset -v dvd_id

# Unmount the dvd media.

if ! sudo umount $volume
then
	error_exit "$LINENO: Error after trying to unmount media."
fi

unset -v volume
