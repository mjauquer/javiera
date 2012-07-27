#! /bin/bash

# backupdb.flib <Core functions of the backupdb.bash script.>
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

source ~/code/bash/backupdb/filetype/filetype.flib
source ~/code/bash/backupdb/upvars/upvars.bash
source ~/code/bash/backupdb/shell-scripts/functions/backupdb-archive.bash
source ~/code/bash/backupdb/shell-scripts/functions/backupdb-audio.bash

delete_file () {

#       USAGE: delete_file HANDLE ID
#
# DESCRIPTION: Delete from the database all the records corresponding
#              with ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      A number value related to the id column of the
#                      database's file table.

	! is_archived $1 archived $2 && return 1
	! is_indvd $1 indvd $2 && return 1

	# If it's an archived file or has been burned to a DVD do not
	# delete from db. Instead, set
	# NULL "pathname" and "hostname" columns in "file" table.
	if [ \( $archived == true \) -o \( $indvd == true \) ]
	then
		shsql $1 $(printf '
			DELETE FROM l_file_to_host
				WHERE file_id = %b;
			' $2)
		[[ $? -ne 0 ]] && return 1
		shsql $1 $(printf '
			UPDATE file SET path_id = NULL
				WHERE id = %b;
			' $2)
		[[ $? -ne 0 ]] && return 1
		return 0
	fi

	! is_archivefile $1 archiver $2 && return 1

	# If it's an archiver file, before deleting it from the db,
	# delete from "archive" table every row with a value of ID in
	# "archiver" column.
	if [ $archiver == true ]
	then
		shsql $1 $(printf '
			DELETE FROM archive WHERE archiver="%b";
			' $2)
		[[ $? -ne 0 ]] && return 1
		delete_orphans $1
		[[ $? -ne 0 ]] && return 1
	fi
	local mimetype=$(shsql $1 $(printf '
		SELECT type
			FROM file
			INNER JOIN mime_type
				ON file.mime_type_id = mime_type.id
			WHERE file.id="%b";
		' $2))
	[[ $? -ne 0 ]] && return 1
	if [[ $mimetype =~ \"audio/.* ]]
	then
		if ! delete_audiofile $1 $2 
		then
			printf 'libbackupdb.sh: error in delete_audiofile().' 1>&2
			return 1
		fi
	elif [[ $mimetype = \"application/x-iso9660-image\" ]]
	then
		if ! delete_isodata $1 $2
		then
			printf 'libbackupdb.sh: error in delete_isodata
				().' 1>&2
			return 1
		fi
	fi
	shsql $1 $(printf '
		DELETE FROM file WHERE id="%b";
		' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

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

is_insync () {

#       USAGE: is_insync HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: Do a query on the connected database to find out if data
#              about the file pointed by PATHNAME is up to date. Store 
#              "true" in the caller's VARNAME variable if it is so. 
#              Otherwise, store "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.

	local tstamp
	tstamp=$(shsql $1 $(printf '
		SELECT last_updated
		FROM l_file_to_host AS link
		INNER JOIN file ON link.file_id = file.id
		INNER JOIN path ON file.path_id = path.id
		INNER JOIN host ON link.host_id = host.id
		WHERE host.name="%b"
		AND path.name="%b";
		' $3 $4))
	[[ $? -ne 0 ]] && return 1
	tstamp="${tstamp##\"}"
	tstamp="${tstamp%%\"}"
	tstamp=$(date --date="$tstamp" +%s)
	local diff
	diff=$(($tstamp-$(stat --format=%Y $4)))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $diff -lt 0 ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
	return 0
}

insert_file () {

#       USAGE: insert_file HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: Collect metadata related to the file pointed by PATHNAME
#              and insert it in the db's file table.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.

	local hostname=$2; hostname=\'$hostname\'
	local pathname=$3; pathname=\'$pathname\'
	local mime_type=$(file -b --mime-type $3)
	mime_type=\'$mime_type\'
	local sha1=$(sha1sum $3 | cut -c1-40)\
	sha1=\'$sha1\'
	local fsize=$(stat --format='%s' $3)
	fsize=\'$fsize\'
	local mtime=$(stat --format='%Y' $3)
	mtime=\'$mtime\'
	mysql --skip-reconnect -u$BACKUPDB_USER \
		-p$BACKUPDB_PASSWORD -e "
		USE javiera;
		CALL insert_file (
			$hostname,
			$pathname,
			$mime_type,
			$sha1,
			$fsize,
			$mtime
		);
	"
	[[ $? -ne 0 ]] && return 1

	# Look at the mime-type of the file being registered in order to
	# determine in what tables, rows must been inserted.
	file_type=( $(mysql --skip-reconnect -u$BACKUPDB_USER \
		-p$BACKUPDB_PASSWORD -e "
		USE javiera;
		CALL select_ancestor (
			'file type hierarchy',
			'regular',
			$mime_type
		);
	") )
	[[ $? -ne 0 ]] && return 1

	local lastid=$(mysql --skip-reconnect -u$BACKUPDB_USER \
		-p$BACKUPDB_PASSWORD -e "
		SELECT LAST_INSERT_ID();
	")
	[[ $? -ne 0 ]] && return 1

	case ${file_type[-1]} in
		audio)   ! insert_audiofile $1 $3 $lastid && return 1
			 ;;
                archive) ! insert_archivefile $1 $lastid $mime_type &&
			 return 1
		         ;;
	esac
	return 0
}

update_file () {

#       USAGE: update_file HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: Collect metadata related to the file pointed by PATHNAME
#              and update all the related records in the database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.

	local id=$(shsql $1 $(printf '
		SELECT id 
		FROM file INNER JOIN path ON file.path_id = path.id
		INNER JOIN host ON file.host_id = host.id
		WHERE host.name="%b"
		AND path.name="%b";
		' $2 $3))
	! is_archived $1 archived $id && return 1
	if [ $archived == "true" ]
	then
		! insert_file $1 $2 $3 && return 1
	else
		shsql $1 $(printf '
			UPDATE file
			SET fsize="%b", mtime="%b" 
			WHERE sha1="%b";
			' $(stat --format='%s %Y' $3) \
			$(sha1sum $3 | cut -c1-40))
		[[ $? -ne 0 ]] && return 1
		if [[ $(file -b --mime-type $3) =~ audio/.* ]]
		then
			! update_audiofile $1 $file $id && return 1
		fi
	fi
	return 0
}
