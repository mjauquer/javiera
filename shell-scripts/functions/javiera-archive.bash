#! /bin/bash

# javiera-archive.bash <Archive file related functions for the javiera.bash script.>
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

insert_archive_file () {

#       USAGE: insert_archive_file QUERY_FILE
#
# DESCRIPTION: Insert in the 'archive_file' table the file whose id in
#              the 'file' table is FILE_ID.
#
#  PARAMETERS: QUERY_FILE  The pathname of the file into which append
#                          the sql query.

	# Insert an entry in the 'archive_file' table.

	printf "CALL insert_archive_file (@file_id);\n" >> $1

	return 0
}
