#! /bin/bash

# javiera.flib <Core functions of the javiera.bash script.>
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
# REQUIREMENTS: shellsql <http://sourceforge.net/projects/shellsql/>
#               upvars.bash, filetype.flib
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

source ~/projects/javiera/upvars/upvars.bash
source ~/projects/javiera/shell-scripts/functions/javiera-archive.bash
source ~/projects/javiera/shell-scripts/functions/javiera-audio.bash

delete_orphans () {

#       USAGE: delete_orphans HANDLE
#
# DESCRIPTION: Delete from table "file" all the records with
#              pathname=NULL which do not exist as archived in table
#              archive.
#
#  PARAMETERS: HANDLE  A connection to a database.

	shsql $1 $(printf '
		DELETE FROM file
		WHERE file.path_id IS NULL
		AND NOT EXISTS (SELECT archived FROM archive WHERE
		file.id=archive.archived);
		' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

escape_chars () {

#       USAGE: escape_chars VARNAME STRING
#
# DESCRIPTION: Edit STRING inserting backslashes in order to escape SQL
#              special characters. Store the resulting string in
#              caller's VARNAME variable.
#
#  PARAMETERS: VARNAME The name of a caller's variable.
#              STRING  The string to be edited.

	local string="$2"
	string=${string//\"/\\\"}
	string=${string//\'/\\\'}
	local $1 && upvar $1 "$string"
}

get_id () {

#       USAGE: get_id HANDLE VARNAME HOSTNAME PATHNAME
#
# DESCRIPTION: Query the backup database for a file id number. Store the
#              result in the caller's VARNAME variable.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.

	! is_backedup $1 backedup $3 $4 && return 1
	if [ $backedup == true ]
	then
		local id
		id=$(shsql $1 $(printf '
			SELECT file.id
			FROM l_file_to_host AS link
			INNER JOIN file ON link.file_id = file.id
			INNER JOIN path ON file.path_id = path.id
			INNER JOIN host ON link.host_id = host.id
			WHERE host.name="%b"
			AND path.name="%b";
			' $3 $4))
		[[ $? -ne 0 ]] && return 1
		local $2 && upvar $2 $id
	fi
}

is_backedup () {

#       USAGE: is_backedup HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: Do a query on the connected database to find out if data
#              about the file pointed by PATHNAME already exists in the
#              database. Store "true" in the caller's VARNAME variable
#              if it is so. If ther is a record with a sha1 value
#              corresponding to the file being query and no value for
#              columns 'pathname' and 'hostname', store "recycle".
#              Otherwise, store "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.

	local shamatch
	local answer
	shamatch=$(shsql $1 $(printf '
		SELECT COUNT(*)
		FROM file
		WHERE sha1="%b";
		' $(sha1sum $4 | cut -c1-40)))
	[[ $? -ne 0 ]] && return 1
	if [ $shamatch == '"1"' ]
	then
		answer=true
	else
		answer=false
	fi
	local $2 && upvar $2 $answer
}

process_file () {

#       USAGE: process_file HOSTNAME PATHNAME
#
# DESCRIPTION: Collect metadata related to the file located in HOSTNAME
#              pointed by PATHNAME and call the pertinent procedures in
#              the database.
#
#  PARAMETERS: HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.

	local lastid_bef=$(mysql --skip-reconnect -u$user -p$pass \
		--skip-column-names -e "

		USE javiera;
		SELECT MAX(id) FROM file;

	")
	[[ $? -ne 0 ]] && return 1

	# Get the uuid of the file system where the file beeing
	# processed is located, and the pathname of the file relative to
	# that file system.
	local -a mpoints        # The matching mount points array.
	local -a mpoints_length # The matching mount points' length
	                        # array.
	# Get the matching mount points.
	for (( i=0; i<${#mount_points[@]}; i++ ))
	do
		if [[ $2 =~ ${mount_points[i]}.* ]]
		then
			mpoints+=( ${mount_points[i]} )
			mpoints_length+=( ${#mount_points[i]} )
		fi
	done
	unset -v i
	# Get the longest matching mount point.
	local -i longest
	local -i max
	for (( i=0; i<${#mpoints_length[@]}; i++ ))
	do
		if [[ ${mpoints_length[i]} -gt $max ]]
		then
			longest=$i; max=${mpoints_length[i]}
		fi
	done
	# Get the wanted data.
	local file_sys=${file_systems[longest]}; file_sys=\'$file_sys\'
	local pathname=${2#${mpoints[longest]}}; pathname=\'$pathname\'

	# Get rest of needed data about the file.
	local mime_type=$(file -b --mime-type $2)
	mime_type=\'$mime_type\'
	local sha1=$(sha1sum $2 | cut -c1-40)
	sha1=\'$sha1\'
	local fsize=$(stat --format='%s' $2)
	fsize=\'$fsize\'
	local mtime=$(stat --format='%Y' $2)
	mtime=\'$mtime\'

	# Insert file's metadata in the database.
	local lastid=$(mysql --skip-reconnect -u$user -p$pass \
		--skip-column-names -e "

		USE javiera;
		CALL process_file (
			$file_sys,
			$pathname,
			$mime_type,
			$sha1,
			$fsize,
			$mtime
		);
		SELECT MAX(id) FROM file;

	")
	[[ $? -ne 0 ]] && return 1

	# If there was not an insertion, return 0
	[[ $lastid_bef == $lastid ]] && return 0

	# Look at the mime-type of the inserted file in order to
	# determine in what tables, rows must been inserted.
	file_type=( $(mysql --skip-reconnect -u$user -p$pass \
		--skip-column-names -e "

		USE javiera;
		CALL select_ancestor (
			'file type hierarchy',
			'regular',
			$mime_type
		);

	") )
	[[ $? -ne 0 ]] && return 1

	case ${file_type[-1]} in
		audio)   ! insert_audio_file $2 $lastid && return 1
			 ;;
		archive) ! insert_archive_file $lastid && return 1
			 ;;
	esac
	return 0
}

process_fstab () {

#       USAGE: process_fstab
#
# DESCRIPTION: Parse file systems data and insert it in the database.

	local hostname=$(hostname); hostname=\'$hostname\'

	while read line
	do
		local fields=( $line )
		if [[ ${fields[0]} =~ UUID=.* ]]
		then
			local field0=${fields[0]}
			local fs_uuid=${field0#UUID=}
			file_systems+=( $fs_uuid )
			local device_name=$(blkid -U $fs_uuid)
			mount_points+=( ${fields[1]} )
			device_name=\'$device_name\'
			fs_uuid=\'$fs_uuid\'
			mysql --skip-reconnect -u$user -p$pass \
				--skip-column-names -e "

				USE javiera;
				CALL insert_hard_disk_partition (
					$hostname,
					$device_name,
					$fs_uuid
				);

			"
			[[ $? -ne 0 ]] && return 1
		elif [[ ${fields[1]} =~ /.* ]] &&
			[[ ! ${fields[1]} =~ \dev.* ]] &&
			[[ ! ${fields[0]} =~ \#.* ]] &&
			[[ -f ${fields[1]}/.javiera/info.txt ]]
		then
				while read line
				do
				if [[ $line =~ UUID=.* ]]
				then
				file_systems+=( ${line#UUID=} )
				mount_point+=( ${fields[1]} )
				fi
				done < ${fields[1]}/.javiera/info.txt
		fi
	done < /etc/fstab

	for (( i=0; i<${#file_systems[@]}; i++ ))
	do
		local file_system=${file_systems[i]}
		file_system=\'$file_system\'
		local mount_point=${mount_points[i]}
		mount_point=\'$mount_point\'
		mysql --skip-reconnect -u$user -p$pass \
			--skip-column-names -e "

			USE javiera;
			CALL insert_mount_point (
				$mount_point,
				$file_system
			);

		"
		[[ $? -ne 0 ]] && return 1
	done
}