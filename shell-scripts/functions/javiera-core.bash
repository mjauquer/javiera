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

	local hostname=$1; hostname=\'$hostname\'
	local pathname=$2; pathname=\'$pathname\'
	local mime_type=$(file -b --mime-type $2)
	mime_type=\'$mime_type\'
	local sha1=$(sha1sum $2 | cut -c1-40)
	sha1=\'$sha1\'
	local fsize=$(stat --format='%s' $2)
	fsize=\'$fsize\'
	local mtime=$(stat --format='%Y' $2)
	mtime=\'$mtime\'
	local lastid=$(mysql --skip-reconnect -u$user -p$pass \
		--skip-column-names -e "

		USE javiera;
		CALL process_file (
			$hostname,
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
		archive) ! insert_archive_file $2 $lastid && return 1
			 ;;
	esac
	return 0
}
