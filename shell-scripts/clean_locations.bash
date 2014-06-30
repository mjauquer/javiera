#! /bin/bash

# clean_locations.bash (See description below).
# Copyright (C) 2013  Marcelo Javier Auquer
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
#  DESCRIPTION: Delete from the database any entry related to a file
#               system location that no longer exists in the specified
#               file system.
#
# REQUIREMENTS: --
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/.myconf/javiera.cnf || exit 1

usage () {

#       USAGE: usage
#
# DESCRIPTION: Print a help message to stdout.

	cat <<- EOF
	Usage: clean_locations FILE_SYSTEM_UUID

	Delete from the database any entry related to a file system
	location that no longer exists in the file system specified by
	FILE_SYSTEM_UUID.
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
	usage && exit 1
elif [[ ! ( $1 =~ ^(.){8}-(.){4}-(.){4}-(.){4}-(.){12}$ || $1 =~ ^(.){16}$ ) ]]
then
	error_exit "Argument must be a well-formatted uuid."
fi

# Get from the database the location ids related to the specified file
# system.
declare -a location_ids
declare fs_uuid=\'$1\'

location_ids=( $($mysql_path --skip-reconnect -u$user -p$pass -D$db \
	--skip-column-names -e "

	SELECT loc.id
		FROM location AS loc
		INNER JOIN file_system_location AS fs_loc
			ON loc.id = fs_loc.location_id
		INNER JOIN file_system AS fs
			ON fs.id = fs_loc.file_system_id
		WHERE fs.uuid = $fs_uuid
	;
") )
[[ $? -ne 0 ]] && error_exit "Error after querying the database"

# For every pathname in the database related to a retrieved location id,
# validate if it already exist as a pathname in the specified file
# system. If it doesn't, delete the location from the database.
declare mount_point

mount_point=$($mysql_path --skip-reconnect -u$user -p$pass -D$db \
	--skip-column-names -e "

	SELECT mount_point.pathname
		FROM mount_point
		INNER JOIN l_file_system_to_mount_point AS link
			ON link.mount_point_id = mount_point.id
		WHERE link.file_system_id = (SELECT fs.id
		                             	FROM file_system AS fs
						WHERE fs.uuid = $fs_uuid)
	;
")
[[ $? -ne 0 ]] && error_exit "Error after querying the database"

for id in ${location_ids[@]}
do 
	id=\'$id\'
	pathname=$($mysql_path --skip-reconnect -u$user -p$pass -D$db \
		--skip-column-names -e "

	SELECT fs_loc.pathname
		FROM location AS loc
		INNER JOIN file_system_location AS fs_loc
			ON loc.id = fs_loc.location_id
		WHERE loc.id = $id
		;
	")
	[[ $? -ne 0 ]] && error_exit "Error after querying the database"
	if [ ! -f ${mount_point}${pathname} ]
	then
		$mysql_path --skip-reconnect -u$admin_user -p$admin_pass -D$db \
			--skip-column-names -e "

			DELETE FROM location
				WHERE location.id = $id
			;
		"
		echo "DELETED ${mount_point}${pathname}."
	fi
done
