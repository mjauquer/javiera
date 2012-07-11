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
source ~/code/bash/backupdb/shell-scripts/functions/backupdb-audio.bash

#===  FUNCTION =========================================================
#
#       USAGE: escape_chars VARNAME STRING
#
# DESCRIPTION: Edit STRING inserting backslashes in order to escape SQL
#              special characters. Store the resulting string in
#              caller's VARNAME variable.
#
#  PARAMETERS: VARNAME The name of a caller's variable.
#              STRING  The string to be edited.
#
escape_chars () {
	local string="$2"
	string=${string//\"/\\\"}
	string=${string//\'/\\\'}
	local $1 && upvar $1 "$string"
}

#===  FUNCTION =========================================================
#
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
#
get_id () {
	! is_backedup $1 backedup $3 $4 && return 1
	if [ $backedup == "true" ]
	then
		local id
		id=$(shsql $1 $(printf 'SELECT id FROM file WHERE 
			hostname="%b" AND pathname="%b";' $3 $4))
		[[ $? -ne 0 ]] && return 1
		local $2 && upvar $2 $id
	fi
}

#===  FUNCTION =========================================================
#
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
#
is_backedup () {
	local match
	local match2
	local answer
	match=$(shsql $1 $(printf 'SELECT COUNT(*) FROM file WHERE
		hostname="%b" AND pathname="%b";' $3 $4))
	[[ $? -ne 0 ]] && return 1
	match2=$(shsql $1 $(printf 'SELECT COUNT(*) FROM file WHERE
		sha1="%b" AND hostname="" AND pathname="";' \
		$(sha1sum $4 | cut -c1-40)))
	[[ $? -ne 0 ]] && return 1
	if [ $match == '"1"' ]
	then
		answer=true
	elif [ $match2 == '"1"' ]
	then
		answer=recycle
	else
		answer=false
	fi
	local $2 && upvar $2 $answer
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
	count=$(shsql $1 $(printf 'SELECT COUNT(*) FROM archive
		WHERE archived=%b;' $3))
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
	count=$(shsql $1 $(printf 'SELECT COUNT(*) FROM dvd
		WHERE image_file=%b;' $3))
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
#       USAGE: is_archiver HANDLE ID
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
is_archiver () {
	local count
	count=$(shsql $1 $(printf 'SELECT COUNT(*) FROM archive
		WHERE archiver=%b;' $3))
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
#
is_insync () {
	local tstamp
	tstamp=$(shsql $1 $(printf 'SELECT last_updated FROM 
		file WHERE hostname="%b" AND pathname="%b";' $3 $4))
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

#===  FUNCTION =========================================================
#
#       USAGE: insert_archive HANDLE ARCHIVER_ID ARCHIVED_ID
#
# DESCRIPTION: Insert in the archive table of the backup database a row.
#
#  PARAMETERS: HANDLE      A connection to a database.
#              ARCHIVER_ID The file id number of the archiver file. Must
#                          be passed between <">.
#              ARCHIVED_ID The file id number of the archived file. Must
#                          be passed between <">.
#
insert_archive () {
	shsql $1 $(printf 'INSERT INTO archive (archiver, archived,
		archived_suffix) VALUES (%b, %b, "%b");' $2 $3 $4)
	[[ $? -ne 0 ]] && return 1
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
	shsql $1 $(printf 'INSERT INTO dvd (image_file, dvd_type,
		dvd_trademark) VALUES (%b, "%b", "%b");' $2 $3 $4)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
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
#
insert_file () {
	local answer
	local lastid
	shsql $1 $(printf 'INSERT INTO file (mimetype, hostname, 
		pathname, sha1, fsize, mtime) VALUES ("%b", 
		"%b", "%b", "%b", "%b", "%b");' \
		$(file -b --mime-type $3) $2 $3 \
		$(sha1sum $3 | cut -c1-40) $(stat --format='%s %Y' $3))
	[[ $? -ne 0 ]] && return 1
	lastid=$(shsql $1 "SELECT LAST_INSERT_ID();")
	if [[ $(file -b --mime-type $3) =~ audio/.* ]]
	then
		! insert_audiofile $1 $3 $lastid && return 1
	fi
	is_iso answer $3
	[[ $? -ne 0 ]] && return 1
	if [ $answer == true ]
	then
		! insert_iso $1 $lastid && return 1
	fi
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
	shsql $1 $(printf 'INSERT INTO iso_metadata (file_id) VALUE
		(%b);' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: delete_file HANDLE ID
#
# DESCRIPTION: Delete from the database all the records corresponding
#              with ID.
#
#  PARAMETERS: HANDLE  A connection to a database.
#              ID      A number value related to the id column of the
#                      database's file table.
#
delete_file () {
	! is_archived $1 archived $2 && return 1
	! is_indvd $1 indvd $2 && return 1

	# If it's an archived file or has been burned to a DVD do not
	# delete from db. Instead, set
	# NULL "pathname" and "hostname" columns in "file" table.
	if [ \( $archived == true \) -o \( $indvd == true \) ]
	then
		shsql $1 $(printf 'UPDATE file SET pathname="",
			hostname="" WHERE id=%b;' $2)
		[[ $? -ne 0 ]] && return 1
		return 0
	fi

	! is_archiver $1 archiver $2 && return 1

	# If it's an archiver file, before deleting it from the db,
	# delete from "archive" table every row with a value of ID in
	# "archiver" column.
	if [ $archiver == true ]
	then
		shsql $1 $(printf 'DELETE FROM archive WHERE
			archiver="%b";' $2)
		[[ $? -ne 0 ]] && return 1
		delete_orphans $1
		[[ $? -ne 0 ]] && return 1
	fi
	local mimetype
	mimetype=$(shsql $1 $(printf 'SELECT mimetype FROM file 
		WHERE id="%b";' $2))
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
	shsql $1 $(printf 'DELETE FROM file WHERE id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: delete_orphans HANDLE
#
# DESCRIPTION: Delete from table "file" all the records with
#              pathname=NULL which do not exist as archived in table
#              archive.
#
#  PARAMETERS: HANDLE  A connection to a database.
#
delete_orphans () {
	shsql $1 $(printf 'DELETE FROM file WHERE file.pathname IS NULL
		AND NOT EXISTS (SELECT archived FROM archive WHERE
		file.id=archive.archived);' $2)
	[[ $? -ne 0 ]] && return 1
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
	shsql $1 $(printf 'DELETE FROM iso_metadata WHERE 
		file_id="%b";' $2)
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
#       USAGE: recycle_file HANDLE HOSTNAME PATHNAME
#
# DESCRIPTION: If there is a record in 'file' table with the sha1 value
#              of the file pointed by PATHNAME and no value for columns
#              'pathname'and 'hostname', reuse that record to insert
#              metadata about that file in the database.
#
#  PARAMETERS: HANDLE    A connection to a database.
#              HOSTNAME  The name of the host machine where the file it
#                        is being query about is stored. 
#              PATHNAME  The pathname of the file it is being query
#                        about.
#
recycle_file () {
	shsql $1 $(printf 'UPDATE file SET mimetype="%b", hostname="%b", 
		pathname="%b", fsize="%b", mtime="%b" WHERE sha1="%b" 
		AND hostname="" AND pathname="";' \
		$(file -b --mime-type $3) $2 $3 \
		$(stat --format='%s %Y' $3) \
		$(sha1sum $3 | cut -c1-40))
	[[ $? -ne 0 ]] && return 1
	return 0
}

#===  FUNCTION =========================================================
#
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
#
update_file () {
	local id=$(shsql $1 $(printf 'SELECT id FROM file WHERE 
		hostname="%b" AND pathname="%b";' $2 $3))
	! is_archived $1 archived $id && return 1
	if [ $archived == "true" ]
	then
		! insert_file $1 $2 $3 && return 1
	else
		shsql $1 $(printf 'UPDATE file SET mimetype="%b",
			hostname="%b", pathname="%b", fsize="%b", 
			mtime="%b" WHERE sha1="%b";' \
			$(file -b --mime-type $3) $2 $3 \
			$(stat --format='%s %Y' $3) \
			$(sha1sum $3 | cut -c1-40))
		[[ $? -ne 0 ]] && return 1
		if [[ $(file -b --mime-type $3) =~ audio/.* ]]
		then
			! update_audiofile $1 $file $id && return 1
		fi
	fi
	return 0
}