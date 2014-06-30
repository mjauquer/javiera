#! /bin/bash

# clean_database.bash <Do jobs of maintenance on the database.>
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# REQUIREMENTS: mysql
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

error_exit () {

#       USAGE: error_exit [MESSAGE]
#
# DESCRIPTION: Function for exit due to fatal program error.
#
#   PARAMETER: MESSAGE An optional description of the error.

	echo "${progname}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

delete_outdated_locations () {

#       USAGE: delete_outdated_locations QUERY_FILE
#
# DESCRIPTION: Search the database for file system locations that are no
#              longer related to a file and build a sql query in order
#              to delete their entries from the tables
#              `file_system_location', `location' and
#              `l_file_to_location'.
#
#   PARAMETER: QUERY_FILE: The pathname of the file in which to append
#                          the sql query.

	fs_ids=( $($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		START TRANSACTION;
		SELECT link.file_system_id
			FROM l_file_system_to_mount_point AS link
			INNER JOIN mount_point
				ON link.mount_point_id = mount_point.id
			INNER JOIN host
				ON mount_point.host_id = host.id
			WHERE host.name = $hostname;
		COMMIT;

	") )
	[[ $? -ne 0 ]] && "delete_outdated_locations(): error after querying the database." && return 1

	m_points=( $($mysql_path --skip-reconnect -u$user -p$pass \
		-D$db --skip-column-names -e "

		START TRANSACTION;
		SELECT mount_point.pathname
			FROM l_file_system_to_mount_point AS link
			INNER JOIN mount_point
				ON link.mount_point_id = mount_point.id
			INNER JOIN host
				ON mount_point.host_id = host.id
			WHERE host.name = $hostname;
		COMMIT;

	") )
	[[ $? -ne 0 ]] && "delete_outdated_locations(): error after querying the database." && return 1

	declare fs_id
	declare -a fsloc_id
	for (( i=0; i < ${#fs_ids[@]}; i++ ))
	do
		fs_id=\'${fs_ids[i]}\'
		declare -a fsloc_ids # An array with the id of every file
				     # system location whose file_system_id
				     # is ${fs_id[i]}.

		fsloc_ids+=( $($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			START TRANSACTION;
			SELECT id 
				FROM file_system_location
				WHERE file_system_id = $fs_id;
			COMMIT;

		") )
		[[ $? -ne 0 ]] && "delete_outdated_locations(): error after querying the database." && return 1

		declare -a fsloc_paths # An array with the pathname of every
				       # file system location whose 
				       # file_system_id is ${fs_id[i]}.

		fsloc_path+=( $($mysql_path --skip-reconnect -u$user -p$pass \
			-D$db --skip-column-names -e "

			START TRANSACTION;
			SELECT pathname
				FROM file_system_location
				WHERE file_system_id = $fs_id;
			COMMIT;

		") )
		[[ $? -ne 0 ]] && "delete_outdated_locations(): error after querying the database." && return 1

		for (( j=0; j < ${#fsloc_ids[@]}; j++ ))
		do
			if [ $fsloc_path ] && ! [ -f ${m_points[i]}${fsloc_path[j]} ]
			then
				fsloc_id=\'${fsloc_ids[j]}\'
				printf "DELETE location.*
						FROM location
						INNER JOIN file_system_location AS fs_loc
							ON location.id = fs_loc.location_id
						WHERE fs_loc.id = %b;\n" $fsloc_id >> $1
			fi
		done
		unset -v fsloc_path
	done
}

#-----------------------------------------------------------------------
# BEGINNING OF MAIN CODE
#-----------------------------------------------------------------------

declare hostname    # The name of the host where this script will be
                    # running.
declare progname    # The name of this script.
declare admin_user  # A mysql user name.
declare admin_pass  # A mysql password.
declare user        # A mysql user name.
declare pass        # A mysql password.
declare db          # A mysql database.
declare -a fs_ids   # An array with the id of every file system in
                    # the current host which has an entry in the
		    # `l_file_system_to_mount_point' table.
declare -a m_points # An array with the pathname of every mount point
                    # the current host which has an entry in the
		    # `l_file_system_to_mount_point' table.
declare cle_tmpdir  # A Temporal directory for use of this script.

hostname=$(hostname); hostname=\'$(hostname)\'
progname=$(basename $0)

source ~/.myconf/javiera.cnf || exit 1

# Create a temporal directory for use of this script.

cle_tmpdir="$(mktemp -d /dev/shm/javiera/cle.XXX)"
[[ $? -ne 0 ]] && error_exit "mktemp: could not create a temporal directory."
cle_tmpdir="$(readlink -f $cle_tmpdir)"
[[ $? -ne 0 ]] && error_exit "readlink: could not read the temporal directory pathname."

# Create a temporal file for use of this script.

> $cle_tmpdir/cle_query.mysql

# Call cleaning functions.

delete_outdated_locations $cle_tmpdir/cle_query.mysql
[ $? -ne 0 ] && error_exit "Error after a call to delete_outdated_locations()."

$mysql_path --skip-reconnect -u$admin_user -p$admin_pass -D$db \
	--skip-column-names -e "

	START TRANSACTION;
	source $cle_tmpdir/cle_query.mysql
	COMMIT;
"
[ $? -ne 0 ] && error_exit "Error after querying the database."

# Delete the temporal directory.

rm -r $cle_tmpdir
[[ $? -ne 0 ]] && error_exit "Could not remove temporal directory."
