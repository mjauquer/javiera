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

insert_archive_file () {

#       USAGE: insert_archive_file PATHNAME FILE_ID
#
# DESCRIPTION: Collect metadata related to the archive file pointed by
#              PATHNAME and insert it in all the related tables in the
#              database.
#
#  PARAMETERS: PATHNAME  A unix filesystem formatted string. 
#              FILE_ID   The value of the 'id' column in the 'file'
#                        table of the database.

	# Insert an entry in the 'archive_file' table and get the
	# archive_file_id.
	local file_id=$2; file_id=\"$file_id\"

	mysql --skip-reconnect -u$user -p$pass \
		--skip-column-names -e "

		USE javiera;
		CALL insert_archive_file (
			$file_id
		);
	"
	[[ $? -ne 0 ]] && return 1

	return 0
}
