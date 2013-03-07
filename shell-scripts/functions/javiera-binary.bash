#! /bin/bash

# javiera-binary.bash <Binary files related functions for the javiera.bash script.>
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
# REQUIREMENTS: --
#         BUGS: --
#        NOTES: Any suggestion is welcomed at auq..r@gmail.com (fill in
#               the dots).

insert_binary_file () {

#       USAGE: insert_binary_file PATHNAME QUERY_FILE
#
# DESCRIPTION: Collect metadata related to the binary file pointed by
#              PATHNAME and insert it in the 'binary_file' table in the
#              database.
#
#  PARAMETERS: PATHNAME    A unix filesystem formatted string. 
#              QUERY_FILE  The pathname of the file into which append
#                          the sql query.

	local filetype="$(file -b $1)"
	if [[ $filetype == 'Parity Archive Volume Set' ]]
	then
		# Insert an entry in the 'binary_file' table.
		printf "CALL insert_binary_file (@file_id);\n" >> $2
	fi

	return 0
}
