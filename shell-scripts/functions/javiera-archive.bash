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

source ~/code/bash/javiera/filetype/filetype.flib
source ~/code/bash/javiera/upvars/upvars.bash

#===  FUNCTION =========================================================
#
#       USAGE: insert_archive HANDLE ARCHIVER_ID ARCHIVED_ID
#
# DESCRIPTION: Insert in the archive table of the backup database a row.
#
#  PARAMETERS: HANDLE      A connection to a database.
#              ID          The file id number of the archived file. Must
#                          be passed between <">.
#              ARCHIVE     The archive file id number of the archiver
#                          file. Must be passed between <">.
#
insert_filetoarchive () {
	shsql $1 $(printf '
		INSERT INTO l_file_to_archive_file (file_id,
			archive_file_id)
		VALUES (%b, %b);
		' $2 $3)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_archive_file HANDLE ID 'MIME'
#
# DESCRIPTION: Insert a row in the table 'archive_file' with the value
#              ID in the column 'file_id'.
#
#  PARAMETERS: HANDLE A connection to a database.
#              ID     An id value of the column 'id' in the table
#                     'file'.
#              MIME   The mime-type of the file.
insert_archivefile () {
	shsql $1 $(printf '
		INSERT INTO archive_file (file_id) VALUE (%b);
		' $2)
	[[ $? -ne 0 ]] && return 1
	local lastid=$(shsql $1 "SELECT LAST_INSERT_ID();")
	[[ $? -ne 0 ]] && return 1
	file_type=( $(mysql -u$JAVIERA_USER -p$JAVIERA_PASSWORD -e "USE javiera; CALL select_ancestor('file type hierarchy', 'archive', $mime_type);") )
	[[ $? -ne 0 ]] && return 1
	case ${file_type[-1]} in
		"disk image")    ! insert_diskimagefile $lastid $2 &&
		                 return 1
			         ;;
	esac
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_dvd HANDLE IMAGE_ID DVD_TYPE DVD_TRADEMARK
#
# DESCRIPTION: Insert in the archive table of the backup database a row.
#
#  PARAMETERS: HANDLE        A connection to a database.
#              IMAGE_ID      The file id number of the image file. Must
#                            be passed between <">.
#              DVD_TYPE      The type of the DVD burned. Usually, DVD-R,
#                            DVD+R, etc. Must be passed between <">.
#              DVD_TRADEMARK The trademark or manufacturer of the DVD.
#                            Must be passed between <">.
#
insert_dvd () {
	shsql $1 $(printf '
		INSERT INTO dvd (image_file, dvd_type, dvd_trademark)
		VALUES (%b, "%b", "%b");
		' $2 $3 $4)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: insert_iso HANDLE PATHNAME ID
#
# DESCRIPTION: Collect metadata related to the iso file pointed by
#              PATHNAME and insert it in the related table in the
#              database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              ID        A number value related to the id column of the
#                        database's file table.
insert_iso () {
	shsql $1 $(printf '
		INSERT INTO iso_metadata (file_id) VALUE (%b);
		' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: is_archived VARNAME HANDLE ID
#
# DESCRIPTION: Do a query on the connected database to find out if ID
#              matchs the "archived" column of any row in the table
#              "archive" in the backup database. Store "true" in the
#              caller's VARNAME variable if it is so. Otherwise, store
#              "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              ID        A number value related to the id column of the
#                        database's file table.
#
is_archived () {
	local count
	count=$(shsql $1 $(printf '
		SELECT COUNT(*)
			FROM l_file_to_archive_file
		       	WHERE file_id=%b;
		' $3))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $count == '"0"' ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: is_archivefile HANDLE ID
#
# DESCRIPTION: Do a query on the connected database to find out if ID
#              matchs the "archiver" column of any row in the table
#              "archive" in the backup database. Store "true" in the
#              caller's VARNAME variable if it is so. Otherwise, store
#              "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              ID        A number value related to the id column of the
#                        database's file table.
#
is_archivefile () {
	local count
	count=$(shsql $1 $(printf '
		SELECT COUNT(*)
			FROM archive_file
			WHERE file_id=%b;
		' $3))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $count == '"0"' ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: is_indvd HANDLE ID
#
# DESCRIPTION: Do a query on the connected database to find out if ID
#              matchs the "image_file" column of any row in the table
#              "dvd" in the backup database. Store "true" in the
#              caller's VARNAME variable if it is so. Otherwise, store
#              "false".
#
#  PARAMETERS: HANDLE    A connection to a database.
#              VARNAME   The name of a caller's variable.
#              ID        A number value related to the id column of the
#                        database's file table.
#
is_indvd () {
	local count
	count=$(shsql $1 $(printf '
		SELECT COUNT(*) FROM dvd WHERE image_file=%b;
		' $3))
	[[ $? -ne 0 ]] && return 1
	local answer
	if [ $count == '"0"' ]
	then
		answer="false"
	else
		answer="true"
	fi
	local $2 && upvar $2 $answer
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: delete_isodata HANDLE ID
#
# DESCRIPTION: Delete from the database all the records corresponding
#              with ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      A number value related to the id column of the
#                      database's file table.
#
delete_isodata () {
	shsql $1 $(printf '
		DELETE FROM iso_metadata WHERE file_id="%b";
		' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}
